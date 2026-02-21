import argparse
import shutil
import subprocess
import urllib.request
import zipfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_ISIC_DIR = PROJECT_ROOT / "raw" / "isic"
TASK1_TRAINING_MASK_ZIP_URL = (
    "https://isic-archive.s3.amazonaws.com/challenges/2018/"
    "ISIC2018_Task1_Training_GroundTruth.zip"
)


def resolve_isic_binary(explicit_path: str | None = None) -> str:
    if explicit_path:
        return explicit_path

    on_path = shutil.which("isic")
    if on_path:
        return on_path

    venv_bin = PROJECT_ROOT / ".venv" / "bin" / "isic"
    if venv_bin.exists():
        return str(venv_bin)

    raise FileNotFoundError(
        "Could not find `isic` CLI. Install it or pass --isic-bin /path/to/isic."
    )


def run_cmd(cmd: list[str], dry_run: bool = False) -> None:
    print("$ " + " ".join(cmd))
    if dry_run:
        return
    subprocess.run(cmd, check=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download ISIC images + metadata via ISIC CLI."
    )
    parser.add_argument(
        "--collection-id",
        type=int,
        default=63,
        help="ISIC collection ID (default: 63, Challenge 2018 Task 1-2 Training).",
    )
    parser.add_argument(
        "--images-dir",
        type=Path,
        default=RAW_ISIC_DIR / "images",
        help="Output directory for downloaded ISIC images.",
    )
    parser.add_argument(
        "--metadata-csv",
        type=Path,
        default=RAW_ISIC_DIR / "metadata" / "collection_63_metadata.csv",
        help="Output CSV path for metadata download.",
    )
    parser.add_argument(
        "--masks-dir",
        type=Path,
        default=RAW_ISIC_DIR / "masks",
        help="Output directory for extracted Task 1 segmentation masks.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit image download count. Use 0 for all images.",
    )
    parser.add_argument(
        "--metadata-limit",
        type=int,
        default=None,
        help="Optional separate metadata limit. Defaults to --limit.",
    )
    parser.add_argument(
        "--skip-images",
        action="store_true",
        help="Skip image download and only download metadata CSV.",
    )
    parser.add_argument(
        "--skip-metadata",
        action="store_true",
        help="Skip metadata download and only download images.",
    )
    parser.add_argument(
        "--isic-bin",
        default=None,
        help="Explicit path to ISIC CLI binary.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without executing them.",
    )
    parser.add_argument(
        "--download-task1-masks",
        action="store_true",
        help=(
            "Download and extract ISIC 2018 Task 1 training masks zip "
            "(useful for U-Net segmentation prep)."
        ),
    )
    parser.add_argument(
        "--task1-mask-zip-url",
        default=TASK1_TRAINING_MASK_ZIP_URL,
        help="Override Task 1 mask ZIP URL.",
    )
    return parser.parse_args()


def download_and_extract_task1_masks(
    zip_url: str, masks_dir: Path, dry_run: bool = False
) -> None:
    archive_path = masks_dir.parent / "ISIC2018_Task1_Training_GroundTruth.zip"
    print(f"$ download {zip_url} -> {archive_path}")
    if dry_run:
        return

    masks_dir.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(zip_url, archive_path)

    extracted = 0
    with zipfile.ZipFile(archive_path) as zf:
        for member in zf.infolist():
            if member.is_dir():
                continue
            member_name = Path(member.filename)
            if member_name.suffix.lower() not in {".png", ".jpg", ".jpeg", ".tif", ".tiff"}:
                continue
            out_path = masks_dir / member_name.name
            with zf.open(member) as src, out_path.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            extracted += 1

    archive_path.unlink(missing_ok=True)
    print(f"Extracted {extracted} mask files into {masks_dir}")


def main() -> None:
    args = parse_args()
    isic_bin = resolve_isic_binary(args.isic_bin)
    metadata_limit = args.limit if args.metadata_limit is None else args.metadata_limit
    collection_id = str(args.collection_id)

    if not args.skip_images:
        args.images_dir.mkdir(parents=True, exist_ok=True)
        image_cmd = [
            isic_bin,
            "image",
            "download",
            "--collections",
            collection_id,
            "--limit",
            str(args.limit),
            str(args.images_dir),
        ]
        run_cmd(image_cmd, dry_run=args.dry_run)

    if not args.skip_metadata:
        args.metadata_csv.parent.mkdir(parents=True, exist_ok=True)
        metadata_cmd = [
            isic_bin,
            "metadata",
            "download",
            "--collections",
            collection_id,
            "--limit",
            str(metadata_limit),
            "--outfile",
            str(args.metadata_csv),
        ]
        run_cmd(metadata_cmd, dry_run=args.dry_run)

    if args.download_task1_masks:
        download_and_extract_task1_masks(
            zip_url=args.task1_mask_zip_url,
            masks_dir=args.masks_dir,
            dry_run=args.dry_run,
        )

    print("\nISIC download flow completed.")
    print(f"Collection: {args.collection_id}")
    print(f"Images dir: {args.images_dir}")
    print(f"Metadata CSV: {args.metadata_csv}")
    print(
        "Note: This ISIC CLI version downloads images + tabular metadata; "
        "segmentation masks are not fetched by `metadata download`. "
        "Use --download-task1-masks for ISIC 2018 Task 1 masks."
    )


if __name__ == "__main__":
    main()
