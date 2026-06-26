# Project Structure

## Current Status
This is a new project. The following structure is suggested and should be adapted based on the chosen technology stack.

## Suggested Project Organization

### For Full-Stack Web Application
```
busana-prima/
├── frontend/                 # Frontend application
│   ├── public/              # Static assets
│   ├── src/
│   │   ├── components/      # Reusable UI components
│   │   ├── pages/          # Page components
│   │   ├── services/       # API service calls
│   │   ├── utils/          # Utility functions
│   │   ├── styles/         # CSS/SCSS files
│   │   └── App.jsx/tsx     # Main application component
│   ├── package.json
│   └── README.md
├── backend/                  # Backend application
│   ├── src/
│   │   ├── controllers/     # Request handlers
│   │   ├── models/          # Data models
│   │   ├── routes/          # API routes
│   │   ├── middleware/      # Custom middleware
│   │   ├── services/        # Business logic
│   │   └── utils/           # Utility functions
│   ├── config/              # Configuration files
│   ├── tests/               # Backend tests
│   └── package.json/requirements.txt
├── shared/                   # Shared code between frontend/backend
│   ├── types/               # TypeScript interfaces/types
│   └── constants/           # Shared constants
├── docs/                    # Documentation
│   ├── api/                 # API documentation
│   ├── architecture/        # Architecture decisions
│   └── user-guides/         # User documentation
├── scripts/                 # Build/deployment scripts
├── tests/                   # Integration/e2e tests
├── docker/                  # Docker configuration
├── .github/                 # GitHub workflows
├── .vscode/                 # VS Code settings
├── .kiro/                   # Kiro configuration (this directory)
│   └── steering/           # Steering documents
├── .gitignore
├── README.md
├── package.json             # Root package.json for monorepo
└── docker-compose.yml       # Local development environment
```

### For Fashion E-commerce Specific Structure
```
busana-prima/
├── product-catalog/         # Product management
│   ├── categories/          # Category hierarchy
│   ├── products/           # Product listings
│   └── inventory/          # Stock management
├── user-management/         # Customer/Admin users
│   ├── authentication/     # Login/registration
│   ├── profiles/          # User profiles
│   └── permissions/       # Role-based access
├── order-management/        # Shopping cart & orders
│   ├── cart/              # Shopping cart
│   ├── checkout/          # Checkout process
│   └── orders/            # Order history
├── payment-processing/      # Payment integration
├── shipping/               # Shipping calculations
└── analytics/              # Sales/reporting
```

## Naming Conventions

### File Naming
- **JavaScript/TypeScript**: Use camelCase for files (e.g., `userService.ts`)
- **Components**: Use PascalCase (e.g., `ProductCard.jsx`)
- **CSS/SCSS**: Use kebab-case (e.g., `product-card.scss`)
- **Configuration**: Use kebab-case (e.g., `database-config.json`)

### Folder Naming
- Use kebab-case for folder names (e.g., `user-management`, `product-catalog`)
- Keep folder names singular for collections (e.g., `product/` not `products/`)

## Code Organization Principles

1. **Feature-based Structure**: Group files by feature/domain rather than by technical layer
2. **Separation of Concerns**: Keep UI, business logic, and data access separate
3. **Reusability**: Extract common components and utilities
4. **Testability**: Structure code to facilitate unit and integration testing
5. **Scalability**: Design for future growth and feature additions

## Import/Export Patterns

- Use named exports for utilities and helper functions
- Use default exports for components and pages
- Group related exports in index files for cleaner imports
- Avoid circular dependencies

## Documentation Structure

- Each major module should have a README.md explaining its purpose
- Complex functions should include JSDoc/TypeDoc comments
- API endpoints should be documented with OpenAPI/Swagger
- Architecture decisions should be recorded in ADRs (Architecture Decision Records)