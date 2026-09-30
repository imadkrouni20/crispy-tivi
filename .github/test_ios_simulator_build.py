#!/usr/bin/env python3
"""Exercise simulator Rust target selection and universal archive packaging."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="crispy-ios-sim-build-") as temp:
        temp_path = Path(temp)
        bin_dir = temp_path / "bin"
        bin_dir.mkdir()
        rustup = bin_dir / "rustup"
        rustup.write_text("#!/bin/sh\nexit 0\n")
        rustup.chmod(0o755)

        cargo = bin_dir / "cargo"
        cargo.write_text(
            "#!/bin/bash\n"
            "target=''\n"
            "while (($#)); do\n"
            "  if [[ $1 == --target ]]; then target=$2; shift 2; else shift; fi\n"
            "done\n"
            "mkdir -p \"target/$target/release\"\n"
            "touch \"target/$target/release/libcrispy_ffi.a\"\n"
            "printf '%s\\n' \"$target\" >> \"$CARGO_TARGET_LOG\"\n"
        )
        cargo.chmod(0o755)

        lipo = bin_dir / "lipo"
        lipo.write_text(
            "#!/bin/bash\n"
            "printf '%s\\n' \"$*\" > \"$LIPO_LOG\"\n"
            "while (($#)); do\n"
            "  if [[ $1 == -output ]]; then output=$2; shift 2; else shift; fi\n"
            "done\n"
            "printf universal > \"$output\"\n"
        )
        lipo.chmod(0o755)

        project_root = temp_path / "project"
        (project_root / "scripts").mkdir(parents=True)
        (project_root / "rust").mkdir()
        (project_root / "app/flutter/ios").mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/build_rust.sh", project_root / "scripts/build_rust.sh")

        cargo_log = temp_path / "cargo-targets.txt"
        lipo_log = temp_path / "lipo-args.txt"
        env = dict(
            os.environ,
            PATH=f"{bin_dir}:{os.environ['PATH']}",
            CARGO_TARGET_LOG=str(cargo_log),
            LIPO_LOG=str(lipo_log),
        )
        subprocess.run(
            ["bash", str(project_root / "scripts/build_rust.sh"), "ios-simulator"],
            cwd=project_root,
            env=env,
            check=True,
            capture_output=True,
            text=True,
        )

        targets = cargo_log.read_text().splitlines()
        assert targets == ["aarch64-apple-ios-sim", "x86_64-apple-ios"], targets
        lipo_args = lipo_log.read_text()
        assert "target/aarch64-apple-ios-sim/release/libcrispy_ffi.a" in lipo_args
        assert "target/x86_64-apple-ios/release/libcrispy_ffi.a" in lipo_args
        packaged = project_root / "app/flutter/ios/Frameworks/libcrispy_ffi.a"
        assert packaged.read_text() == "universal"
        packaged.unlink()
        packaged.parent.rmdir()

    print("iOS simulator universal archive behavior passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
