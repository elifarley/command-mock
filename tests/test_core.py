"""
Core tests for Command Mock Framework.
Tests Recorder, Player, and Matching logic in isolation.
"""
import pytest
import subprocess
from pathlib import Path
from unittest.mock import patch, MagicMock
from command_mock.player import CommandMockPlayer
from command_mock.recorder import CommandMockRecorder

# --- 1. Logic Tests (No I/O) ---

class TestMatchingLogic:
    """Test the command matching algorithm directly."""

    def setup_method(self):
        self.player = CommandMockPlayer("git")

    def test_exact_match(self):
        template = ["git", "log"]
        assert self.player.command_matches(["git", "log"], template)
        assert not self.player.command_matches(["git", "status"], template)

    def test_embedded_placeholder(self):
        """Test placeholders like --grep={term}"""
        template = ["git", "log", "--grep={term}"]
        assert self.player.command_matches(["git", "log", "--grep=fix"], template)
        assert self.player.command_matches(["git", "log", "--grep=feat"], template)
        assert not self.player.command_matches(["git", "log", "--other=fix"], template)

    def test_standalone_placeholder(self):
        """Test placeholders like {filepath}"""
        template = ["git", "add", "{filepath}"]
        assert self.player.command_matches(["git", "add", "file.txt"], template)
        assert self.player.command_matches(["git", "add", "src/main.py"], template)

    def test_dynamic_flag_stripping(self):
        """Test that dynamic flags like --since are ignored during matching."""
        template = ["git", "log"]
        # The player is configured to strip --since by default in logic
        assert self.player.command_matches(["git", "log", "--since", "1 day ago"], template)


# --- 2. IO Tests (Recorder & Player) ---

class TestPersistence:
    """Test that we can record commands and play them back."""

    def test_record_and_replay(self, tmp_path):
        # 1. Setup environment
        fixtures_root = tmp_path
        mock_file_rel = Path("scenarios.toml")

        # 2. RECORD
        recorder = CommandMockRecorder("test_cmd", fixtures_root=fixtures_root)

        # Mock the actual subprocess call during recording so we don't need real tools
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=["echo", "hello"], returncode=0, stdout="recorded output", stderr=""
            )

            scenario = recorder.record_scenario(
                command=["echo", "{msg}"],
                scenario_name="test_echo",
                output_path=mock_file_rel,
                template_vars={"msg": "hello"}
            )

        # 3. WRITE TOML FILE WITH THE RECORDED SCENARIO
        recorder.generate_mock_file([scenario], mock_file_rel)

        # 4. VERIFY FILE STRUCTURE
        full_toml_path = fixtures_root / "mocks" / "test_cmd" / mock_file_rel
        assert full_toml_path.exists()
        assert "recorded output" in (full_toml_path.parent / "outputs" / "test_echo.txt").read_text()

        # 5. PLAYBACK
        player = CommandMockPlayer("test_cmd", fixtures_root=fixtures_root)
        mock_fn = player.get_subprocess_mock("scenarios.toml", "test_echo")

        # Test match
        with patch("subprocess.run", side_effect=mock_fn):
            # Should match the template ["echo", "{msg}"]
            res = subprocess.run(["echo", "world"], capture_output=True, text=True)
            assert res.stdout == "recorded output"
            assert res.returncode == 0


# --- 3. Integration / Fixture Tests ---

def test_pytest_fixture_integration(command_mock, tmp_path):
    """
    Verify the pytest fixture provided by conftest.py works.
    Uses the existing mocks in tests/mocks/git/log/follow.toml
    """
    # Note: This test relies on the files existing in the repo.
    # If we want to be purely self-contained, we would mock the path in conftest,
    # but for an integration test, using the included 'example' data is acceptable.

    # Load a known scenario from the repo's own test data
    mock_fn = command_mock.get_subprocess_mock("log/follow.toml", "basic")

    with patch("subprocess.run", side_effect=mock_fn):
        # The command must match the template in follow.toml
        result = subprocess.run(
            ["git", "log", "--follow", "--format=%H|%an|%ai", "--", "any_file.py"],
            capture_output=True, text=True
        )

        # We verify it returns the mock data (checking first line structure)
        assert "|" in result.stdout
        assert result.returncode == 0
