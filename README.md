# 📦 ISA-VESIT Inventory Management System

A robust Inventory Management System built using **Flutter** and **Supabase**, designed to streamline inventory tracking and item issuance for ISA-VESIT. The system includes two Flutter applications:
- **Member App**: For general members to view inventory and council info.
- **Admin App**: For council members to manage items, issue/return assets, and track transaction history.

---

## ✨ Features

### ✅ Common Features (Both Apps)
- 🔍 Searchable and categorized inventory items
- 📄 View detailed item information (e.g., stock, SKU, category)
- 📲 Push notifications via **OneSignal**

### 👤 Member App
- View available items in inventory
- Council information section
- Request access or usage of specific items

### 🔐 Admin App
- Issue/Return inventory items
- Add/Remove/Edit item details
- View transaction logs and history
- Member management
- Role-based access control

---

## 🛠️ Tech Stack

| Layer          | Tech Used                         |
|----------------|----------------------------------|
| Frontend       | Flutter                          |
| Backend (DB)   | Supabase (PostgreSQL)            |
| Notifications  | OneSignal                        |
| Authentication | Supabase Auth                    |
| Hosting        | Supabase + Vercel (for backend)  |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.10)
- Dart
- Supabase Project
- OneSignal Account

### Clone the repo
```bash
git clone https://github.com/CharChips/inventory.git
cd inventory
