from pathlib import Path
from pathlib import PurePosixPath
import io
import inspect
import re
import os
import subprocess
import sys
import tarfile
import tempfile
import unittest


WORKFLOWS = Path(__file__).with_name("workflows")
ROOT = WORKFLOWS.parent.parent

def job_blocks(workflow):
    text = workflow.read_text()
    blocks = {}
    jobs_start = text.index("jobs:\n")
    job_text = text[jobs_start + len("jobs:\n"):]
    matches = list(re.finditer(r"(?m)^  ([A-Za-z0-9_-]+):\s*$", job_text))
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(job_text)
        blocks[match.group(1)] = job_text[match.start():end]
    return text, blocks


def safe_extract(archive, destination):
    root = destination.resolve()
    for member in archive.getmembers():
        member_path = PurePosixPath(member.name)
        if member_path.is_absolute() or ".." in member_path.parts:
            raise ValueError(f"unsafe archive member path: {member.name}")
        target = (root / Path(*member_path.parts)).resolve()
        if target != root and root not in target.parents:
            raise ValueError(f"archive member escapes destination: {member.name}")
        if member.issym():
            link_target = (target.parent / member.linkname).resolve()
            if link_target != root and root not in link_target.parents:
                raise ValueError(f"archive symlink escapes destination: {member.name}")
        elif member.islnk():
            raise ValueError(f"archive hard links are not supported: {member.name}")
        elif not (member.isdir() or member.isfile()):
            raise ValueError(f"unsupported archive member type: {member.name}")
        if "filter" in inspect.signature(archive.extract).parameters:
            archive.extract(member, root, filter="data")
        else:
            archive.extract(member, root)


class RunnerWorktreeContractTests(unittest.TestCase):
    def test_hosted_pr_checkout_matches_workflow_sha(self):
        ci, jobs = job_blocks(WORKFLOWS / "ci.yml")
        prepare = jobs["prepare-pr-worktree"]
        guard = re.search(
            r"(?ms)^      - name: Verify PR checkout matches workflow SHA\n"
            r"        if: github\.event_name == 'pull_request'\n"
            r"        run: ([^\n]+)",
            prepare,
        )
        self.assertIsNotNone(guard)
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp, "pr-worktree")
            repo.mkdir()
            workspace = Path(temp, "runner-workspace")
            workspace.symlink_to(repo, target_is_directory=True)
            def git(*args):
                return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()

            git("init", "-q")
            git("config", "user.email", "runner-contract@example.invalid")
            git("config", "user.name", "Runner Contract")
            default_branch = git("branch", "--show-current")
            Path(repo, "source.txt").write_text("base\n")
            git("add", "source.txt")
            git("commit", "-qm", "base")
            git("checkout", "-qb", "pr")
            Path(repo, "source.txt").write_text("PR head\n")
            git("commit", "-qam", "PR head")
            pr_head = git("rev-parse", "HEAD")
            git("checkout", "-q", default_branch)
            Path(repo, "target.txt").write_text("target\n")
            git("add", "target.txt")
            git("commit", "-qm", "target")
            git("merge", "--no-ff", "-m", "merge PR", "pr")
            merge_sha = git("rev-parse", "HEAD")
            self.assertNotEqual(pr_head, merge_sha)
            self.assertTrue(workspace.is_symlink())

            def check(expected_sha, expected_workspace=workspace):
                env = dict(os.environ, GITHUB_SHA=expected_sha, GITHUB_WORKSPACE=str(expected_workspace))
                return subprocess.run(["bash", "-e", "-c", guard.group(1)], cwd=workspace, env=env, capture_output=True).returncode

            self.assertEqual(check(merge_sha), 0)
            self.assertNotEqual(check(merge_sha, Path(temp, "wrong-root")), 0)
            self.assertNotEqual(check(pr_head), 0)

    def test_prepared_archive_contains_workflow_tree_and_submodules(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        prepare = jobs["prepare-pr-worktree"]
        archive = re.search(
            r"(?ms)^      - name: Archive prepared source at workflow SHA\n"
            r"        run: \|\n((?:          [^\n]*\n)+)",
            prepare,
        )
        self.assertIsNotNone(archive)
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp, "repo")
            repo.mkdir()
            submodule = Path(temp, "submodule")
            submodule.mkdir()
            runner_temp = Path(temp, "runner-temp")
            runner_temp.mkdir()
            def git(*args):
                return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()

            subprocess.run(["git", "init", "-q"], cwd=submodule, check=True)
            subprocess.run(["git", "config", "user.email", "runner-contract@example.invalid"], cwd=submodule, check=True)
            subprocess.run(["git", "config", "user.name", "Runner Contract"], cwd=submodule, check=True)
            Path(submodule, "nested.txt").write_text("submodule source\n")
            subprocess.run(["git", "add", "nested.txt"], cwd=submodule, check=True)
            subprocess.run(["git", "commit", "-qm", "submodule source"], cwd=submodule, check=True)

            git("init", "-q")
            git("config", "user.email", "runner-contract@example.invalid")
            git("config", "user.name", "Runner Contract")
            Path(repo, "tracked.txt").write_text("base\n")
            git("add", "tracked.txt")
            git("commit", "-qm", "base")
            subprocess.run(["git", "-c", "protocol.file.allow=always", "submodule", "add", str(submodule), "vendor/fixture"], cwd=repo, check=True, capture_output=True, text=True)
            git("commit", "-qam", "add submodule")
            git("checkout", "-qb", "pr")
            Path(repo, "tracked.txt").write_text("PR head\n")
            git("commit", "-qam", "PR head")
            pr_head = git("rev-parse", "HEAD")
            default_branch = "master" if "master" in git("branch", "--list").split() else "main"
            git("checkout", "-q", default_branch)
            Path(repo, "target.txt").write_text("target\n")
            git("add", "target.txt")
            git("commit", "-qm", "target")
            git("merge", "--no-ff", "-m", "merge PR", "pr")
            merge_sha = git("rev-parse", "HEAD")
            self.assertNotEqual(pr_head, merge_sha)
            Path(repo, "tracked.txt").write_text("working tree edit\n")
            Path(repo, "untracked.txt").write_text("must not ship\n")
            env = dict(os.environ, GITHUB_SHA=merge_sha, RUNNER_TEMP=str(runner_temp))
            script = "\n".join(line[10:] for line in archive.group(1).splitlines())
            subprocess.run(["bash", "-e", "-c", script], cwd=repo, env=env, check=True)
            with tarfile.open(Path(runner_temp, "source.tar.gz"), "r:gz") as source:
                names = source.getnames()
                self.assertIn("./tracked.txt", names)
                self.assertIn("./target.txt", names)
                self.assertIn("./vendor/fixture/nested.txt", names)
                self.assertNotIn("./untracked.txt", names)
                self.assertIn("./.git/HEAD", names)
                self.assertEqual(source.extractfile("./tracked.txt").read(), b"PR head\n")
                self.assertEqual(source.extractfile("./vendor/fixture/nested.txt").read(), b"submodule source\n")
                extracted = Path(temp, "extracted")
                extracted.mkdir()
                safe_extract(source, extracted)
                self.assertEqual(
                    subprocess.run(["git", "rev-parse", "HEAD"], cwd=extracted, check=True, capture_output=True, text=True).stdout.strip(),
                    merge_sha,
                )

    def test_ci_gates_stop_on_cancellation(self):
        ci, jobs = job_blocks(WORKFLOWS / "ci.yml")
        self.assertIn("cancel-in-progress: false", ci)
        self.assertRegex(jobs["quality"], r"(?ms)- uses: actions/upload-artifact@v4\n        if: always\(\)")
        for name, job in jobs.items():
            if name != "quality":
                self.assertNotRegex(job, r"(?m)^\s+if: .*always\(\)", name)

    def test_safe_extract_rejects_path_traversal_and_external_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            destination = root / "extracted"
            destination.mkdir()
            archive_path = root / "malicious.tar"
            with tarfile.open(archive_path, "w") as archive:
                payload = b"escaped"
                traversal = tarfile.TarInfo("../outside.txt")
                traversal.size = len(payload)
                archive.addfile(traversal, io.BytesIO(payload))
            with tarfile.open(archive_path) as archive:
                with self.assertRaisesRegex(ValueError, "unsafe archive member path"):
                    safe_extract(archive, destination)
            self.assertFalse((root / "outside.txt").exists())

            archive_path = root / "symlink.tar"
            with tarfile.open(archive_path, "w") as archive:
                link = tarfile.TarInfo("escape")
                link.type = tarfile.SYMTYPE
                link.linkname = "../../outside"
                archive.addfile(link)
            with tarfile.open(archive_path) as archive:
                with self.assertRaisesRegex(ValueError, "archive symlink escapes"):
                    safe_extract(archive, destination)
            self.assertFalse((root / "outside").exists())

    def test_one_prepare_checkout_feeds_every_ci_job(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        self.assertEqual(jobs["prepare-pr-worktree"].count("uses: actions/checkout@v4"), 1)
        prepare_checkout = re.search(
            r"(?ms)^      - uses: actions/checkout@v4\n"
            r"        with:\n"
            r"          submodules: recursive\n"
            r"          fetch-depth: 0\n"
            r"          persist-credentials: false",
            jobs["prepare-pr-worktree"],
        )
        self.assertIsNotNone(prepare_checkout)
        for name, job in jobs.items():
            if name == "prepare-pr-worktree":
                continue
            self.assertNotIn("actions/checkout@v4", job, name)
            self.assertIn("actions/download-artifact@v4", job, name)
            self.assertIn("Unpack prepared source", job, name)
            self.assertRegex(job, r"(?m)^    needs: .*(prepare-pr-worktree)", name)

    def test_pull_requests_use_hosted_runners_and_only_main_dispatch_uses_shared(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        shared_jobs = ("prepare-pr-worktree", "rust-test", "flutter-analyze", "flutter-test", "build-android", "build-web", "playwright-web", "build-server", "build-linux")
        for name in shared_jobs:
            runs_on = next(line for line in jobs[name].splitlines() if line.startswith("    runs-on:"))
            self.assertIn("github.event_name == 'workflow_dispatch'", runs_on, name)
            self.assertIn("github.ref == 'refs/heads/main'", runs_on, name)
            self.assertIn("'ubuntu-latest'", runs_on, name)
            self.assertNotIn("github.event.pull_request", runs_on, name)
            self.assertNotIn("pr-{0}-{1}", runs_on, name)
        release = (WORKFLOWS / "release.yml").read_text()
        for name in ("build-linux-android-web", "create-release"):
            runner = re.search(rf"(?ms)^  {name}:\n(.*?)(?=^  [A-Za-z0-9_-]+:|\Z)", release)
            self.assertIsNotNone(runner)
            self.assertIn("github.ref == 'refs/heads/main'", runner.group(1))
            self.assertIn("'ubuntu-latest'", runner.group(1))

    def test_prepare_runs_once_then_publishes_source_for_hosted_jobs(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        prepare = jobs["prepare-pr-worktree"]
        self.assertIn("Verify runner workflow contract", prepare)
        self.assertIn("flutter pub get", prepare)
        self.assertIn("actions/upload-artifact@v4", prepare)
        archive = re.search(r"(?ms)^      - name: Archive prepared source at workflow SHA\n(.*?)(?=^      - )", prepare)
        upload = re.search(r"(?m)^      - uses: actions/upload-artifact@v4\n((?:        [^\n]*\n)+)", prepare)
        self.assertIsNotNone(archive)
        self.assertIsNotNone(upload)
        self.assertNotIn("        if:", archive.group(1))
        self.assertNotIn("        if:", upload.group(1))
        self.assertNotIn("pr-{0}-{1}-run-{2}-attempt-{3}", prepare)
        self.assertNotIn("github.run_id", next(line for line in jobs["prepare-pr-worktree"].splitlines() if line.startswith("    runs-on:")))
        for name in ("golden-tests", "build-windows", "build-macos", "build-ios"):
            self.assertIn("actions/download-artifact@v4", jobs[name], name)
            self.assertIn("Unpack prepared source", jobs[name], name)
        for name in ("golden-tests", "build-windows"):
            self.assertIn("shell: pwsh", jobs[name], name)
            self.assertIn("$env:GITHUB_WORKSPACE", jobs[name], name)
        for name in ("rust-test", "flutter-analyze", "flutter-test", "build-android", "build-web", "playwright-web", "build-server", "build-linux"):
            self.assertRegex(jobs[name], r"(?ms)actions/download-artifact@v4\n        with:", name)
            self.assertRegex(jobs[name], r"(?ms)- name: Unpack prepared source\n        run:", name)

    def test_quality_pr_scan_is_in_the_same_prepared_workflow(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        quality = jobs["quality"]
        self.assertIn("needs: [prepare-pr-worktree]", quality)
        self.assertIn("if: github.event_name == 'pull_request'", quality)
        self.assertIn("--locked --bin rguard", quality)
        self.assertIn("semgrep==$SEMGREP_VERSION", quality)
        self.assertIn("python3 scripts/ci/rguard_scan_gate.py", quality)
        self.assertIn("RICE_GUARD_FAIL_ON: high", quality)
        self.assertIn("rguard-report-${{ github.run_id }}-${{ github.run_attempt }}", quality)
        self.assertIn("actions/download-artifact@v4", quality)
        self.assertIn("Unpack prepared source", quality)
        self.assertNotIn("actions/checkout@v4", quality)
        rguard_config = (ROOT / ".rguard.yaml").read_text()
        self.assertRegex(rguard_config, r"(?ms)^scanners:.*?^  semgrep:\n    enabled: true")
        self.assertRegex(rguard_config, r"(?ms)^tools:.*?^  scanners:\n    semgrep: true")
        gate = (ROOT / "scripts/ci/rguard_scan_gate.py").read_text()
        self.assertIn('["rguard", "scan", ".", "--diff-only"]', gate)
        self.assertIn('("error", "warning")', gate)
        quality_workflow = (WORKFLOWS / "quality.yml").read_text()
        self.assertIn("50aa1c13b9c85c7af3b76d05e6a610194e9367be", (ROOT / ".github/workflows/ci.yml").read_text())
        self.assertNotRegex(quality_workflow, r"(?m)^  pull_request:")
        self.assertRegex(quality_workflow, r"(?m)^  workflow_dispatch:")
        self.assertIn("rguard-report-${{ github.run_id }}-${{ github.run_attempt }}", quality_workflow)
        self.assertIn("runs-on: ubuntu-latest", quality_workflow)
        self.assertIn("python3 scripts/ci/rguard_scan_gate.py", quality_workflow)
        self.assertIn("50aa1c13b9c85c7af3b76d05e6a610194e9367be", quality_workflow)

    def test_quality_gate_behavioral_contract(self):
        test = subprocess.run(
            [sys.executable, ".github/test-rguard-scan-gate.py"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(test.returncode, 0, test.stdout + test.stderr)

    def test_pr_quality_job_preserves_semgrep_child_diagnostics(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        quality = jobs["quality"]
        self.assertIn(".github/semgrep-with-log.py", quality)
        self.assertIn("Preserve scanner diagnostics", quality)
        self.assertIn("rguard-report-${{ github.run_id }}-${{ github.run_attempt }}", quality)

    def test_quality_workflows_pin_setuptools_for_semgrep_imports(self):
        for workflow in ("ci.yml", "quality.yml"):
            text = (WORKFLOWS / workflow).read_text()
            self.assertIn('SETUPTOOLS_VERSION: "80.9.0"', text, workflow)
            self.assertIn('"setuptools==$SETUPTOOLS_VERSION"', text, workflow)

    def test_file_size_baseline_has_unique_paths(self):
        baseline = ROOT / "scripts/ci/file_size_baseline.txt"
        paths = [line.split("|", 1)[0] for line in baseline.read_text().splitlines() if line.strip()]
        self.assertEqual(len(paths), len(set(paths)), "duplicate file-size baseline path")

    def test_rust_jobs_install_linux_build_dependencies(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        for name in ("rust-test", "build-server"):
            self.assertIn("sudo apt-get install -y", jobs[name], name)
            self.assertIn("libdbus-1-dev pkg-config", jobs[name], name)
        self.assertIn("dbus-x11 gnome-keyring", jobs["rust-test"])
        self.assertIn("dbus-run-session -- bash -e -c", jobs["rust-test"])
        self.assertIn("gnome-keyring-daemon --unlock --components=secrets", jobs["rust-test"])
        self.assertIn('HOME="$keyring_home"', jobs["rust-test"])
        self.assertIn('RUSTUP_HOME="$rustup_home"', jobs["rust-test"])
        self.assertIn('XDG_RUNTIME_DIR="$keyring_runtime"', jobs["rust-test"])

    def test_playwright_starts_the_backend_artifact(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        playwright = jobs["playwright-web"]
        self.assertIn("needs: [prepare-pr-worktree, build-web, build-server]", playwright)
        self.assertIn("name: server-linux", playwright)
        self.assertIn("CRISPY_PORT=8081 nohup", playwright)
        self.assertIn("wait-on http://127.0.0.1:8081/health", playwright)
        self.assertIn("crispy-server", playwright)

    def test_dispatch_and_native_platforms_remain_available(self):
        ci, jobs = job_blocks(WORKFLOWS / "ci.yml")
        self.assertRegex(ci, r"(?m)^  pull_request:")
        self.assertRegex(ci, r"(?m)^  workflow_dispatch:")
        for name, platform in (("golden-tests", "windows-latest"), ("build-windows", "windows-latest"), ("build-macos", "macos-latest"), ("build-ios", "macos-latest")):
            self.assertIn(f"runs-on: {platform}", jobs[name], name)
        self.assertRegex((WORKFLOWS / "release.yml").read_text(), r"(?m)^  workflow_dispatch:")


if __name__ == "__main__":
    unittest.main()
