#!/usr/bin/env bash
# UserPromptSubmit inject hook.
# Whatever this prints to stdout is appended to EVERY prompt you send.
#
# Keep this line as it is: the memory block relies on it verbatim.

echo "REMINDER: before answering questions about past decisions, call search_memory (mem0-local)."

exit 0
