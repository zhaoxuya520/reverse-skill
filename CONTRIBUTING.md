# Contributing to reverse-skill

Thank you for your interest in contributing to reverse-skill! This document outlines the process for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/reverse-skill.git`
3. Add the upstream remote: `git remote add upstream https://github.com/zhaoxuya520/reverse-skill.git`
4. Install dependencies: `make install`

## Development Workflow

1. Create a branch from the latest `main`:
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feat/your-feature
   ```

2. Make your changes and test them:
   ```bash
   make test
   ```

3. Commit with a clear message:
   ```bash
   git commit -m "feat: add amazing feature"
   ```

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `test:` - Test additions/changes
- `ci:` - CI/CD changes
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks

## Pull Request Process

1. Ensure your branch is up to date with `main`
2. Run tests and ensure they pass
3. Open a pull request with a clear description of the changes
4. Link any related issues using `Closes #N` syntax
5. Be responsive to review feedback

## Code Style

- Follow the existing code style in the repository
- Keep changes focused and minimal
- Add tests for new functionality
- Update documentation as needed

## Reporting Issues

When reporting issues, please include:
- A clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, language version, etc.)

## Questions?

Feel free to open an issue with the `question` label if you need help getting started.

Thank you for contributing! 🎉
