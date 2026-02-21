import argparse
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DIR = PROJECT_ROOT / "raw"
DEFAULT_DATASETS = ["manuelhettich/acne04"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download Kaggle datasets and normalize nested raw/raw layout."
    )
    parser.add_argument(
        "-d",
        "--dataset",
        action="append",
        default=None,
        help="Kaggle dataset slug (can be passed multiple times).",
    )
    parser.add_argument(
        "--raw-dir",
        type=Path,
        default=DEFAULT_RAW_DIR,
        help="Project raw dataset directory.",
    )
    parser.add_argument(
        "--fix-layout-only",
        action="store_true",
        help="Do not download, only normalize nested raw/raw layout.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands/actions without executing.",
    )
    return parser.parse_args()


def resolve_kaggle_binary() -> str:
    on_path = shutil.which("kaggle")
    if on_path:
        return on_path
    venv_bin = PROJECT_ROOT / ".venv" / "bin" / "kaggle"
    if venv_bin.exists():
        return str(venv_bin)
    raise FileNotFoundError(
        "Could not find `kaggle` CLI. Install it or activate the project .venv."
    )


def run_cmd(cmd: list[str], dry_run: bool = False) -> None:
    print("$ " + " ".join(cmd))
    if dry_run:
        return
    subprocess.run(cmd, check=True)


def merge_path(src: Path, dst: Path, dry_run: bool = False) -> None:
    if src.is_dir():
        if not dst.exists():
            print(f"move dir: {src} -> {dst}")
            if not dry_run:
                shutil.move(str(src), str(dst))
            return
        if not dst.is_dir():
            print(f"skip (destination is file): {dst}")
            return
        for child in sorted(src.iterdir(), key=lambda p: p.name):
            merge_path(child, dst / child.name, dry_run=dry_run)
        if not dry_run:
            try:
                src.rmdir()
            except OSError:
                pass
        return

    if dst.exists():
        print(f"skip (already exists): {dst}")
        return
    print(f"move file: {src} -> {dst}")
    if not dry_run:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dst))


def normalize_nested_raw(raw_dir: Path, dry_run: bool = False) -> None:
    nested_raw = raw_dir / "raw"
    if not nested_raw.exists():
        print(f"No nested layout found at {nested_raw}.")
        return

    print(f"Normalizing nested layout: {nested_raw} -> {raw_dir}")
    for item in sorted(nested_raw.iterdir(), key=lambda p: p.name):
        merge_path(item, raw_dir / item.name, dry_run=dry_run)

    if not dry_run:
        try:
            nested_raw.rmdir()
        except OSError:
            pass


def main() -> None:
    args = parse_args()
    raw_dir = args.raw_dir
    raw_dir.mkdir(parents=True, exist_ok=True)

    datasets = args.dataset if args.dataset else DEFAULT_DATASETS

    if not args.fix_layout_only:
        kaggle_bin = resolve_kaggle_binary()
        for dataset_slug in datasets:
            cmd = [
                kaggle_bin,
                "datasets",
                "download",
                "-d",
                dataset_slug,
                "-p",
                str(raw_dir),
                "--unzip",
            ]
            run_cmd(cmd, dry_run=args.dry_run)

    normalize_nested_raw(raw_dir, dry_run=args.dry_run)
    print("Kaggle download/layout step complete.")


if __name__ == "__main__":
    main()
