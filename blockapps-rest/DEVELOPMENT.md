
## Code Quality Tools

### ESLint
We use ESLint v9 with TypeScript support for code linting and static analysis.

**Configuration**: `eslint.config.js`
- Uses the new flat config format (ESLint v9+)
- Based on recommended JavaScript and TypeScript rules
- Separate configurations for JavaScript and TypeScript files
- Special rules for test files
- Ignore patterns are defined in the config file

**Usage**:
```bash
# Check for linting issues
npm run lint

# Automatically fix linting issues
npm run lint:fix
```

### Prettier
We use Prettier for consistent code formatting.

**Configuration**: `.prettierrc`
- Single quotes
- Semicolons enabled
- 2-space indentation
- 100 character line width
- Trailing commas (ES5 compatible)

**Usage**:
```bash
# Format all files
npm run format

# Check if files are properly formatted
npm run format:check
```

### TypeScript
Type checking is performed using the TypeScript compiler.

**Usage**:
```bash
# Run type checking
npm run type-check
```

## Development Workflow

### Before Committing
Run the comprehensive check command to ensure code quality:

```bash
# Check types, linting, and formatting
npm run check
```

### Auto-fix Issues
If there are fixable issues, run:

```bash
# Fix linting and formatting issues automatically
npm run fix
```

### IDE Setup

#### VS Code
Install these recommended extensions:
- ESLint
- Prettier - Code formatter
- TypeScript and JavaScript Language Features

Add to your VS Code settings:
```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  }
}
```

#### Other IDEs
Ensure your IDE supports:
- EditorConfig (uses `.editorconfig`)
- ESLint integration
- Prettier integration

## File Organization

### Ignored Files
The following files/directories are ignored by linting and formatting tools:
- `node_modules/`
- `dist/` and `lib/` (build outputs)
- `docs/` (generated documentation)
- Test fixtures with intentional issues (`src/test/fixtures/`, `src/util/test/fixtures/`)
- Generated files (`*.min.js`, `*.bundle.js`)
- Legacy files (`gulpfile.js`)

**Note**: ESLint ignores are now defined in `eslint.config.js` using the flat config format.

### Configuration Files
- `eslint.config.js` - ESLint configuration (flat config format for v9+)
- `.prettierrc` - Prettier configuration
- `.prettierignore` - Files ignored by Prettier
- `.editorconfig` - Editor configuration
- `tsconfig.json` - TypeScript configuration

## Migration to ESLint v9

This project has been migrated to ESLint v9 which uses the new "flat config" format. Key changes:

- **Configuration file**: `.eslintrc.json` → `eslint.config.js`
- **Ignore file**: `.eslintignore` → ignores defined in config file
- **Format**: JSON → JavaScript ES modules
- **Compatibility**: Requires Node.js 18.18.0 or higher

If you see errors about missing `eslint.config.js`, make sure you've updated your dependencies:
```bash
npm install
# or
yarn install
```

## Common Issues

### TypeScript Rules
- Use `const` instead of `let` when possible
- Avoid `any` type (warnings allowed)
- Unused variables starting with `_` are allowed
- Explicit return types recommended for functions

### Formatting
- Use single quotes for strings
- Include trailing commas where valid
- Maximum line length: 100 characters
- Use 2 spaces for indentation 