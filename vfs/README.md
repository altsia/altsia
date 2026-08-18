# kokic/vfs

A platform-independent virtual filesystem for workspace paths.

- `Path` — a POSIX-normalized logical path; all operations accept both
  `/` and `\` separators and always produce `/`-separated results.
- `Workspace` — a virtual filesystem rooted at an arbitrary root path,
  resolving relative and absolute paths inside the workspace.
