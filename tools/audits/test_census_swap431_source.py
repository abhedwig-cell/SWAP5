"""Lexical edge cases that affect source-selector discoverability."""
import unittest

from census_swap431_source import is_control_branch, logical_statements


class SourceNavigationLexing(unittest.TestCase):
    def test_quoted_comment_and_semicolon(self):
        source = "call rdscha('a!b;c', value); if (sw == 1) call run() ! omitted"
        self.assertEqual(list(logical_statements(source)), [
            (1, 1, "call rdscha('a!b;c', value)"),
            (1, 1, "if (sw == 1) call run()")])

    def test_doubled_quote(self):
        self.assertEqual(list(logical_statements("call read('isn''t!;x'); call next()")), [
            (1, 1, "call read('isn''t!;x')"), (1, 1, 'call next()')])

    def test_continuation_and_empty_comment(self):
        source = "if (sw == 1 .and. &\n! intervening comment\n & mode == 2) call read( &\n 'option', value)"
        self.assertEqual(list(logical_statements(source)), [
            (1, 4, "if (sw == 1 .and. mode == 2) call read( 'option', value)")])

    def test_branch_terminators_are_not_paths(self):
        for statement in ['end if', 'endif', 'end select', 'call classify(value)']:
            self.assertFalse(is_control_branch(statement))
        for statement in ['if (sw == 1) then', 'else if (sw == 2) then',
                          'choice: select case (sw)', 'case default', 'case (1,2)']:
            self.assertTrue(is_control_branch(statement))


if __name__ == '__main__':
    unittest.main()
