import argparse
import csv
import hashlib
import json
import re
import shutil
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_ROOT = PROJECT_ROOT / "raw"
PROCESSED_ROOT = PROJECT_ROOT / "processed"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".webp"}
MASK_EXTS = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare ACNE + ISIC datasets into deterministic train/val/test splits."
    )
    parser.add_argument("--train-ratio", type=float, default=0.7)
    parser.add_argument("--val-ratio", type=float, default=0.2)
    parser.add_argument("--test-ratio", type=float, default=0.1)
    parser.add_argument(
        "--keep-existing",
        action="store_true",
        help="Do not clear existing processed outputs before staging.",
    )
    return parser.parse_args()


def ensure_valid_split(train_ratio: float, val_ratio: float, test_ratio: float) -> None:
    total = train_ratio + val_ratio + test_ratio
    if abs(total - 1.0) > 1e-8:
        raise ValueError(
            f"Split ratios must sum to 1.0, got {train_ratio} + {val_ratio} + {test_ratio} = {total}"
        )


def assign_split(sample_key: str, train_ratio: float, val_ratio: float) -> str:
    digest = hashlib.sha1(sample_key.encode("utf-8")).hexdigest()
    value = int(digest[:8], 16) / 0xFFFFFFFF
    if value < train_ratio:
        return "train"
    if value < train_ratio + val_ratio:
        return "val"
    return "test"


def find_existing_dirs(candidates: list[Path]) -> list[Path]:
    return [p for p in candidates if p.exists() and p.is_dir()]


def extract_acne_label(stem: str) -> str | None:
    match = re.match(r"levle([0-3])_", stem)
    if not match:
        return None
    return match.group(1)


def path_priority(path: Path, prioritized_dirs: tuple[str, ...]) -> tuple[int, int]:
    parts = set(path.parts)
    for idx, marker in enumerate(prioritized_dirs):
        if marker in parts:
            return (idx, len(path.parts))
    return (len(prioritized_dirs), len(path.parts))


def collect_acne_images() -> dict[str, dict[str, str | Path]]:
    acne_dirs = find_existing_dirs(
        [
            RAW_ROOT / "acne_1024",
            RAW_ROOT / "raw" / "acne_1024",
        ]
    )
    chosen: dict[str, tuple[tuple[int, int], Path, str]] = {}
    for acne_dir in acne_dirs:
        for file in acne_dir.rglob("*"):
            if file.suffix.lower() not in IMAGE_EXTS:
                continue
            label = extract_acne_label(file.stem)
            if label is None:
                continue
            score = path_priority(
                file,
                (
                    "all_1024",
                    "acne0_1024",
                    "acne1_1024",
                    "acne2_1024",
                    "acne3_1024",
                    "small_1024",
                    "small_1024_renamed",
                ),
            )
            previous = chosen.get(file.stem)
            if previous is None or score < previous[0]:
                chosen[file.stem] = (score, file, label)

    return {
        stem: {"image": record[1], "label": record[2]}
        for stem, record in sorted(chosen.items(), key=lambda x: x[0])
    }


def extract_isic_id(stem: str) -> str | None:
    match = re.search(r"(ISIC_\d+)", stem, flags=re.IGNORECASE)
    if not match:
        return None
    return match.group(1).upper()


def collect_isic_images() -> dict[str, Path]:
    isic_dirs = find_existing_dirs(
        [
            RAW_ROOT / "isic" / "images",
            RAW_ROOT / "raw" / "isic" / "images",
            RAW_ROOT / "isic",
            RAW_ROOT / "raw" / "isic",
        ]
    )
    chosen: dict[str, tuple[tuple[int, int], Path]] = {}
    for isic_dir in isic_dirs:
        for file in isic_dir.rglob("*"):
            if file.suffix.lower() not in IMAGE_EXTS:
                continue
            isic_id = extract_isic_id(file.stem)
            if not isic_id:
                continue
            score = path_priority(file, ("images", "ISIC_2018_Training_Input"))
            previous = chosen.get(isic_id)
            if previous is None or score < previous[0]:
                chosen[isic_id] = (score, file)
    return {k: v[1] for k, v in sorted(chosen.items(), key=lambda x: x[0])}


def collect_isic_masks() -> dict[str, Path]:
    mask_dirs = find_existing_dirs(
        [
            RAW_ROOT / "isic" / "masks",
            RAW_ROOT / "raw" / "isic" / "masks",
            RAW_ROOT / "isic",
            RAW_ROOT / "raw" / "isic",
        ]
    )
    chosen: dict[str, tuple[tuple[int, int], Path]] = {}
    for mask_dir in mask_dirs:
        for file in mask_dir.rglob("*"):
            if file.suffix.lower() not in MASK_EXTS:
                continue
            isic_id = extract_isic_id(file.stem)
            if not isic_id:
                continue
            score = path_priority(
                file, ("masks", "GroundTruth", "ground_truth", "groundtruth")
            )
            previous = chosen.get(isic_id)
            if previous is None or score < previous[0]:
                chosen[isic_id] = (score, file)
    return {k: v[1] for k, v in sorted(chosen.items(), key=lambda x: x[0])}


def copy_file(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    headers = [
        "dataset",
        "task",
        "split",
        "sample_id",
        "label",
        "image_path",
        "mask_path",
        "source_image",
        "source_mask",
    ]
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows)


def clean_outputs() -> None:
    for path in [
        PROCESSED_ROOT / "acne_classification",
        PROCESSED_ROOT / "isic_segmentation",
        PROCESSED_ROOT / "manifests",
    ]:
        if path.exists():
            shutil.rmtree(path)
    summary_path = PROCESSED_ROOT / "dataset_summary.json"
    if summary_path.exists():
        summary_path.unlink()


def stage_acne(
    train_ratio: float, val_ratio: float, acne_samples: dict[str, dict[str, str | Path]]
) -> tuple[list[dict[str, str]], dict[str, int]]:
    out_root = PROCESSED_ROOT / "acne_classification" / "images"
    rows: list[dict[str, str]] = []
    counts = {"train": 0, "val": 0, "test": 0, "total": 0}

    for sample_id, sample in acne_samples.items():
        split = assign_split(f"acne:{sample_id}", train_ratio, val_ratio)
        label = str(sample["label"])
        src_image = Path(str(sample["image"]))
        dst_image = out_root / split / f"class_{label}" / src_image.name
        copy_file(src_image, dst_image)

        rows.append(
            {
                "dataset": "acne04",
                "task": "classification",
                "split": split,
                "sample_id": sample_id,
                "label": label,
                "image_path": str(dst_image.relative_to(PROJECT_ROOT)),
                "mask_path": "",
                "source_image": str(src_image.relative_to(PROJECT_ROOT)),
                "source_mask": "",
            }
        )
        counts[split] += 1
        counts["total"] += 1

    return rows, counts


def stage_isic(
    train_ratio: float, val_ratio: float, isic_images: dict[str, Path], isic_masks: dict[str, Path]
) -> tuple[list[dict[str, str]], dict[str, int]]:
    out_images = PROCESSED_ROOT / "isic_segmentation" / "images"
    out_masks = PROCESSED_ROOT / "isic_segmentation" / "masks"
    rows: list[dict[str, str]] = []
    counts = {"train": 0, "val": 0, "test": 0, "total": 0, "missing_mask": 0}

    for sample_id, src_image in sorted(isic_images.items()):
        src_mask = isic_masks.get(sample_id)
        if src_mask is None:
            counts["missing_mask"] += 1
            continue

        split = assign_split(f"isic:{sample_id}", train_ratio, val_ratio)
        dst_image = out_images / split / f"{sample_id}{src_image.suffix.lower()}"
        dst_mask = out_masks / split / f"{sample_id}{src_mask.suffix.lower()}"
        copy_file(src_image, dst_image)
        copy_file(src_mask, dst_mask)

        rows.append(
            {
                "dataset": "isic_2018_task1_2",
                "task": "segmentation",
                "split": split,
                "sample_id": sample_id,
                "label": "lesion",
                "image_path": str(dst_image.relative_to(PROJECT_ROOT)),
                "mask_path": str(dst_mask.relative_to(PROJECT_ROOT)),
                "source_image": str(src_image.relative_to(PROJECT_ROOT)),
                "source_mask": str(src_mask.relative_to(PROJECT_ROOT)),
            }
        )
        counts[split] += 1
        counts["total"] += 1

    return rows, counts


def main() -> None:
    args = parse_args()
    ensure_valid_split(args.train_ratio, args.val_ratio, args.test_ratio)
    PROCESSED_ROOT.mkdir(parents=True, exist_ok=True)

    if not args.keep_existing:
        clean_outputs()

    acne_samples = collect_acne_images()
    isic_images = collect_isic_images()
    isic_masks = collect_isic_masks()

    acne_rows, acne_counts = stage_acne(args.train_ratio, args.val_ratio, acne_samples)
    isic_rows, isic_counts = stage_isic(
        args.train_ratio, args.val_ratio, isic_images, isic_masks
    )

    write_manifest(PROCESSED_ROOT / "manifests" / "acne_classification.csv", acne_rows)
    write_manifest(PROCESSED_ROOT / "manifests" / "isic_segmentation.csv", isic_rows)
    write_manifest(PROCESSED_ROOT / "manifests" / "all_datasets.csv", acne_rows + isic_rows)

    summary = {
        "split": {
            "train": args.train_ratio,
            "val": args.val_ratio,
            "test": args.test_ratio,
        },
        "acne04": acne_counts,
        "isic_2018_task1_2": isic_counts,
        "notes": [
            "ACNE04 in this project is severity-labeled image data (classification), not lesion bounding boxes.",
            "ISIC segmentation rows require both image and matching mask files.",
        ],
    }
    with (PROCESSED_ROOT / "dataset_summary.json").open("w") as f:
        json.dump(summary, f, indent=2)

    print("Dataset preparation complete.")
    print(json.dumps(summary, indent=2))
    print(
        f"Manifests written to: {(PROCESSED_ROOT / 'manifests').relative_to(PROJECT_ROOT)}"
    )


if __name__ == "__main__":
    main()
