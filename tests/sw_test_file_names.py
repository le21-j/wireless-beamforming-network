"""Check ownership prefixes and the fixed-name exceptions."""

import unittest

from tools.sw_check_file_names import naming_error


class FileNameTests(unittest.TestCase):
    def test_software_files_need_a_team_prefix(self):
        self.assertIsNone(naming_error("tools/sw_network_probe.py"))
        self.assertIsNone(naming_error("docs/sw_m1_team_review.md"))
        self.assertIsNotNone(naming_error("tools/network_probe.py"))

    def test_verilog_files_belong_to_hardware(self):
        for suffix in ("sv", "v", "vh"):
            self.assertIsNone(naming_error(f"fpga/hw_modem.{suffix}"))
            self.assertIsNotNone(naming_error(f"fpga/sw_modem.{suffix}"))

    def test_rf_files_use_the_rf_prefix(self):
        self.assertIsNone(naming_error("rf/rf_calibration.py"))
        self.assertIsNotNone(naming_error("rf/sw_calibration.py"))

    def test_metadata_and_shared_docs_keep_their_names(self):
        for path in ("README.md", ".github/pull_request_template.md",
                     "firmware/net/lwip_ethernet/README.md", "docs/project-plan.md"):
            with self.subTest(path=path):
                self.assertIsNone(naming_error(path))


if __name__ == "__main__":
    unittest.main()
