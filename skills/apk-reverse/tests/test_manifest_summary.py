"""Check declared Android launcher components without a device or APK tools."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "manifest-summary.ps1"
POWERSHELL = (shutil.which("powershell") if os.name == "nt" else None) or shutil.which("pwsh") or shutil.which("powershell")
LAUNCHER = ('<intent-filter><action android:name="android.intent.action.MAIN"/>'
            '<category android:name="android.intent.category.LAUNCHER"/></intent-filter>')


@unittest.skipUnless(POWERSHELL, "PowerShell is unavailable")
class ManifestSummaryTests(unittest.TestCase):
    def summary(self, components):
        with tempfile.TemporaryDirectory() as scratch:
            manifest = Path(scratch) / "AndroidManifest.xml"
            manifest.write_text(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example.fixture">'
                '<uses-sdk android:minSdkVersion="21" android:targetSdkVersion="34"/>'
                '<application>' + components + '</application></manifest>', encoding="utf-8"
            )
            result = subprocess.run([POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                                     str(SCRIPT), "-ManifestPath", str(manifest)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return result.stdout.splitlines()

    def launchers(self, lines):
        return [line for line in lines if line.startswith("main_activity=")]

    def test_ordinary_activity_output_is_preserved(self):
        lines = self.summary('<activity android:name=".Direct" android:exported="true" android:enabled="true">'
                             + LAUNCHER + '</activity>')
        self.assertIn("activity_count=1", lines)
        self.assertIn("activity=.Direct\ttrue\ttrue", lines)
        self.assertEqual(self.launchers(lines), ["main_activity=.Direct"])

    def test_alias_launcher_preserves_nonexported_target_separately(self):
        lines = self.summary('<activity android:name=".Hidden" android:exported="false"/>'
                             '<activity-alias android:name=".Launcher" android:targetActivity=".Hidden" '
                             'android:exported="true" android:enabled="true">' + LAUNCHER + '</activity-alias>')
        self.assertIn("activity_count=1", lines)
        self.assertIn("activity_alias_count=1", lines)
        self.assertIn("activity_alias=.Launcher\ttrue\ttrue\t.Hidden", lines)
        self.assertEqual(self.launchers(lines), ["main_activity=.Launcher"])

    def test_mixed_components_filter_and_deduplicate_launchers(self):
        lines = self.summary('<activity android:name=".Direct" android:exported="true">' + LAUNCHER + '</activity>'
                             '<activity android:name=".Target" android:exported="false"/>'
                             '<activity-alias android:name=".Launcher" android:targetActivity=".Target" '
                             'android:exported="true">' + LAUNCHER + LAUNCHER + '</activity-alias>'
                             '<activity-alias android:name=".Other" android:targetActivity=".Target"/>'
                             '<activity-alias android:name=".SeparateFilters" android:targetActivity=".Target">'
                             '<intent-filter><action android:name="android.intent.action.MAIN"/></intent-filter>'
                             '<intent-filter><category android:name="android.intent.category.LAUNCHER"/></intent-filter>'
                             '</activity-alias>')
        self.assertIn("activity_count=2", lines)
        self.assertIn("activity_alias_count=3", lines)
        self.assertEqual(self.launchers(lines), ["main_activity=.Direct", "main_activity=.Launcher"])

    def test_launcher_listing_remains_a_static_declaration_summary(self):
        lines = self.summary('<activity android:name=".Disabled" android:exported="false" android:enabled="false">'
                             + LAUNCHER + '</activity>'
                             '<activity-alias android:name=".DisabledAlias" android:targetActivity=".Disabled" '
                             'android:exported="false" android:enabled="false">' + LAUNCHER + '</activity-alias>')
        self.assertIn("activity=.Disabled\tfalse\tfalse", lines)
        self.assertIn("activity_alias=.DisabledAlias\tfalse\tfalse\t.Disabled", lines)
        self.assertEqual(self.launchers(lines), ["main_activity=.Disabled", "main_activity=.DisabledAlias"])


if __name__ == "__main__":
    unittest.main()
