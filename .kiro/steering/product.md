# Product Overview

**Busana Prima** — A bespoke tailoring booking and order management system for a single tailor business (Malaysian market).

## Business Model

This is **NOT** a standard e-commerce platform. It is a bespoke tailoring workflow system.

### Pricing Model
- Each product has a `basePrice` (starting tailoring fee for a specific design pattern)
- Final price is calculated dynamically per order item based on:
  1. Customer body size (small, medium, large, custom measurements from 3D scan)
  2. Fabric type (provided by customer or provided by tailor)
  3. Design complexity or customization requests
  4. Additional tailoring adjustments
- `basePrice` = starting price for sewing the design only
- `finalPrice` = calculated dynamically per order item during checkout

### UI Pricing Rule
- Catalog/listing display: **"From RMXXX"** (e.g. "From RM199", "From RM249")
- Exact final price is only determined during checkout after measurements and fabric selection

### Order Structure
- One order can contain multiple outfits
- Each outfit may have different final pricing
- Pricing is calculated per order item, not per order

## Target Users

- **Customers** — Browse designs, book tailoring appointments, provide measurements
- **Tailor (Kak Dah)** — Manage orders, update status, view customer measurements

## Core Features

1. Product catalog (design patterns with base pricing)
2. Digital tailor / 3D body measurement
3. Order booking and management
4. Real-time order status tracking
5. Customer profile with saved measurements

## Tech Stack

- Flutter (mobile-first, Android + Web)
- Firebase (Auth, Firestore, Storage)
- Rowy (admin CMS for managing products/categories/banners)
- Riverpod (state management)
