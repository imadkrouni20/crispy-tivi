from pathlib import Path
import re
import os
import subprocess
import tarfile
import tempfile
import unittest


WORKFLOWS = Path(__file__).with_name("workflows")

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


def pr_label(expression):
    return f"pr-{{0}}-{{1}}" in expression and all(
        context in expression
        for context in (
            "github.repository_id",
            "github.event.pull_request.number",
        )
    )


class RunnerWorktreeContractTests(unittest.TestCase):
    def test_brokered_pr_sha_guard_accepts_only_exact_head(self):
        ci, jobs = job_blocks(WORKFLOWS / "ci.yml")
        prepare = jobs["prepare-pr-worktree"]
        guard = re.search(
            r"(?ms)^      - name: Verify brokered PR checkout matches workflow SHA\n"
            r"        if: github\.event_name == 'pull_request' && github\.event\.pull_request\.head\.repo\.full_name == github\.repository\n"
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

    def test_fork_archive_contains_only_tracked_workflow_merge_tree(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        prepare = jobs["prepare-pr-worktree"]
        archive = re.search(
            r"(?ms)^      - name: Archive fork source at workflow SHA\n"
            r"        if: github\.event_name == 'pull_request' && github\.event\.pull_request\.head\.repo\.full_name != github\.repository\n"
            r"        run: ([^\n]+)",
            prepare,
        )
        self.assertIsNotNone(archive)
        with tempfile.TemporaryDirectory() as repo, tempfile.TemporaryDirectory() as runner_temp:
            def git(*args):
                return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()

            git("init", "-q")
            git("config", "user.email", "runner-contract@example.invalid")
            git("config", "user.name", "Runner Contract")
            Path(repo, "tracked.txt").write_text("base\n")
            git("add", "tracked.txt")
            git("commit", "-qm", "base")
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
            env = dict(os.environ, GITHUB_SHA=merge_sha, RUNNER_TEMP=runner_temp)
            subprocess.run(["bash", "-e", "-c", archive.group(1)], cwd=repo, env=env, check=True)
            with tarfile.open(Path(runner_temp, "source.tar.gz"), "r:gz") as source:
                names = source.getnames()
                self.assertIn("tracked.txt", names)
                self.assertIn("target.txt", names)
                self.assertNotIn("untracked.txt", names)
                self.assertFalse(any(name == ".git" or name.startswith(".git/") for name in names))
                self.assertEqual(source.extractfile("tracked.txt").read(), b"PR head\n")

    def test_ci_gates_stop_on_cancellation(self):
        ci, _ = job_blocks(WORKFLOWS / "ci.yml")
        self.assertIn("cancel-in-progress: false", ci)
        self.assertNotRegex(ci, r"(?m)^\s+if: .*always\(\)")

    def test_one_prepare_checkout_feeds_every_ci_job(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        self.assertEqual(jobs["prepare-pr-worktree"].count("uses: actions/checkout@v4"), 1)
        prepare_checkout = re.search(
            r"(?ms)^      - uses: actions/checkout@v4\n"
            r"        if: ([^\n]+)\n"
            r"        with:\n"
            r"          submodules: recursive\n"
            r"          persist-credentials: false",
            jobs["prepare-pr-worktree"],
        )
        self.assertIsNotNone(prepare_checkout)
        self.assertEqual(
            prepare_checkout.group(1),
            "github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository",
        )
        for name, job in jobs.items():
            if name == "prepare-pr-worktree":
                continue
            if name == "quality":
                checkout = re.search(
                    r"(?ms)^      - uses: actions/checkout@v4\n"
                    r"        if: ([^\n]+)\n"
                    r"        with:\n"
                    r"          ref: \$\{\{ github\.sha \}\}\n"
                    r"          fetch-depth: 0\n"
                    r"          persist-credentials: false",
                    job,
                )
                self.assertIsNotNone(checkout)
                self.assertEqual(
                    checkout.group(1),
                    "github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name != github.repository",
                )
            else:
                self.assertNotIn("actions/checkout@v4", job, name)
            self.assertRegex(job, r"(?m)^    needs: .*(prepare-pr-worktree)", name)

    def test_same_repo_prs_use_one_stable_pr_label_and_forks_stay_hosted(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        for name in ("prepare-pr-worktree", "rust-test", "flutter-analyze", "flutter-test", "build-android", "build-web", "playwright-web", "build-server", "build-linux", "quality"):
            runs_on = next(line for line in jobs[name].splitlines() if line.startswith("    runs-on:"))
            self.assertIn("github.event.pull_request.head.repo.full_name != github.repository && 'ubuntu-latest'", runs_on)
            self.assertTrue(pr_label(runs_on), name)
        self.assertIn("ubuntu-latest", jobs["prepare-pr-worktree"])

    def test_prepare_runs_once_then_publishes_source_for_hosted_jobs(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        prepare = jobs["prepare-pr-worktree"]
        self.assertIn("Verify runner workflow contract", prepare)
        self.assertIn("flutter pub get", prepare)
        self.assertIn("actions/upload-artifact@v4", prepare)
        self.assertIn("github.event.pull_request.head.repo.full_name != github.repository", prepare)
        self.assertNotIn("pr-{0}-{1}-run-{2}-attempt-{3}", prepare)
        self.assertNotIn("github.run_id", next(line for line in jobs["prepare-pr-worktree"].splitlines() if line.startswith("    runs-on:")))
        for name in ("golden-tests", "build-windows", "build-macos", "build-ios"):
            self.assertIn("actions/download-artifact@v4", jobs[name], name)
            self.assertIn("Unpack prepared source", jobs[name], name)
        for name in ("golden-tests", "build-windows"):
            self.assertIn("shell: pwsh", jobs[name], name)
            self.assertIn("$env:GITHUB_WORKSPACE", jobs[name], name)
        for name in ("rust-test", "flutter-analyze", "flutter-test", "build-android", "build-web", "playwright-web", "build-server", "build-linux"):
            self.assertRegex(
                jobs[name],
                r"(?ms)actions/download-artifact@v4\n"
                r"        if: github\.event_name != 'pull_request' \|\| github\.event\.pull_request\.head\.repo\.full_name != github\.repository",
                name,
            )
            self.assertRegex(
                jobs[name],
                r"(?ms)- name: Unpack prepared source\n"
                r"        if: github\.event_name != 'pull_request' \|\| github\.event\.pull_request\.head\.repo\.full_name != github\.repository",
                name,
            )

    def test_quality_pr_scan_is_in_the_same_prepared_workflow(self):
        _, jobs = job_blocks(WORKFLOWS / "ci.yml")
        quality = jobs["quality"]
        self.assertIn("needs: [prepare-pr-worktree]", quality)
        self.assertIn("if: github.event_name == 'pull_request'", quality)
        self.assertIn("https://install.rguard.dev", quality)
        self.assertIn("set -o pipefail", quality)
        self.assertIn("rguard scan . --diff-only", quality)
        quality_workflow = (WORKFLOWS / "quality.yml").read_text()
        self.assertNotRegex(quality_workflow, r"(?m)^  pull_request:")
        self.assertRegex(quality_workflow, r"(?m)^  workflow_dispatch:")

    def test_dispatch_and_native_platforms_remain_available(self):
        ci, jobs = job_blocks(WORKFLOWS / "ci.yml")
        self.assertRegex(ci, r"(?m)^  pull_request:")
        self.assertRegex(ci, r"(?m)^  workflow_dispatch:")
        for name, platform in (("golden-tests", "windows-latest"), ("build-windows", "windows-latest"), ("build-macos", "macos-latest"), ("build-ios", "macos-latest")):
            self.assertIn(f"runs-on: {platform}", jobs[name], name)
        self.assertRegex((WORKFLOWS / "release.yml").read_text(), r"(?m)^  workflow_dispatch:")


if __name__ == "__main__":
    unittest.main()
