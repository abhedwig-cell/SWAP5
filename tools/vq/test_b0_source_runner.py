import unittest

from tools.vq.b0_source_runner import select_dec_branches


class B0SourceRunnerTests(unittest.TestCase):
    def test_selects_standalone_linux_branches(self):
        source = """before\n!DEC$ IF DEFINED (multiswap)\nmulti\n!DEC$ ELSE\nstandalone\n!DEC$ END IF\n!DEC$ IF (linux==0)\nwindows\n!DEC$ END IF\nafter\n"""
        selected = select_dec_branches(source)
        self.assertIn("standalone", selected)
        self.assertNotIn("multi\n", selected)
        self.assertNotIn("windows", selected)
        self.assertIn("before", selected)
        self.assertIn("after", selected)


if __name__ == "__main__":
    unittest.main()
