"""Banking system simulation with multiple accounts, transactions, and reporting."""

import datetime
import random
import string
from enum import Enum


class AccountType(Enum):
    CHECKING = "checking"
    SAVINGS = "savings"
    BUSINESS = "business"


class TransactionType(Enum):
    DEPOSIT = "deposit"
    WITHDRAWAL = "withdrawal"
    TRANSFER = "transfer"
    INTEREST = "interest"
    FEE = "fee"


class TransactionStatus(Enum):
    COMPLETED = "completed"
    PENDING = "pending"
    FAILED = "failed"
    REVERSED = "reversed"


class Transaction:
    def __init__(self, transaction_type, amount, from_account=None,
                 to_account=None, description=""):
        self.id = self._generate_id()
        self.transaction_type = transaction_type
        self.amount = amount
        self.from_account = from_account
        self.to_account = to_account
        self.description = description
        self.timestamp = datetime.datetime.now()
        self.status = TransactionStatus.COMPLETED

    @staticmethod
    def _generate_id():
        chars = string.ascii_uppercase + string.digits
        return "TXN-" + "".join(random.choices(chars, k=10))

    def reverse(self):
        if self.status == TransactionStatus.COMPLETED:
            self.status = TransactionStatus.REVERSED
            return True
        return False

    def __repr__(self):
        return (
            f"Transaction(id={self.id}, type={self.transaction_type.value}, "
            f"amount={self.amount:.2f}, status={self.status.value})"
        )

    def to_dict(self):
        return {
            "id": self.id,
            "type": self.transaction_type.value,
            "amount": self.amount,
            "from_account": self.from_account,
            "to_account": self.to_account,
            "description": self.description,
            "timestamp": self.timestamp.isoformat(),
            "status": self.status.value,
        }


class Account:
    INTEREST_RATES = {
        AccountType.CHECKING: 0.001,
        AccountType.SAVINGS: 0.02,
        AccountType.BUSINESS: 0.005,
    }

    MINIMUM_BALANCE = {
        AccountType.CHECKING: 0.0,
        AccountType.SAVINGS: 100.0,
        AccountType.BUSINESS: 500.0,
    }

    MONTHLY_FEE = {
        AccountType.CHECKING: 5.0,
        AccountType.SAVINGS: 0.0,
        AccountType.BUSINESS: 15.0,
    }

    DAILY_WITHDRAWAL_LIMIT = {
        AccountType.CHECKING: 5000.0,
        AccountType.SAVINGS: 2000.0,
        AccountType.BUSINESS: 25000.0,
    }

    def __init__(self, owner, account_type, initial_deposit=0.0):
        self.account_number = self._generate_account_number()
        self.owner = owner
        self.account_type = account_type
        self.balance = 0.0
        self.transactions = []
        self.is_active = True
        self.created_at = datetime.datetime.now()
        self.daily_withdrawn = 0.0
        self.last_withdrawal_date = None
        self.overdraft_protection = False
        self.overdraft_limit = 0.0

        if initial_deposit > 0:
            self.deposit(initial_deposit, "Initial deposit")

    @staticmethod
    def _generate_account_number():
        return "".join(random.choices(string.digits, k=10))

    def _reset_daily_withdrawal_if_needed(self):
        today = datetime.date.today()
        if self.last_withdrawal_date != today:
            self.daily_withdrawn = 0.0
            self.last_withdrawal_date = today

    def _check_withdrawal_limit(self, amount):
        self._reset_daily_withdrawal_if_needed()
        limit = self.DAILY_WITHDRAWAL_LIMIT[self.account_type]
        if self.daily_withdrawn + amount > limit:
            remaining = limit - self.daily_withdrawn
            raise ValueError(
                f"Daily withdrawal limit exceeded. "
                f"Limit: ${limit:.2f}, Remaining: ${remaining:.2f}"
            )

    def _get_effective_balance(self):
        if self.overdraft_protection:
            return self.balance + self.overdraft_limit
        return self.balance

    def deposit(self, amount, description="Deposit"):
        if not self.is_active:
            raise ValueError("Account is inactive")
        if amount <= 0:
            raise ValueError("Deposit amount must be positive")

        self.balance += amount
        txn = Transaction(
            TransactionType.DEPOSIT,
            amount,
            to_account=self.account_number,
            description=description,
        )
        self.transactions.append(txn)
        return txn

    def withdraw(self, amount, description="Withdrawal"):
        if not self.is_active:
            raise ValueError("Account is inactive")
        if amount <= 0:
            raise ValueError("Withdrawal amount must be positive")

        self._check_withdrawal_limit(amount)

        effective_balance = self._get_effective_balance()
        if amount > effective_balance:
            raise ValueError(
                f"Insufficient funds. Available: ${effective_balance:.2f}"
            )

        min_balance = self.MINIMUM_BALANCE[self.account_type]
        if self.balance - amount < min_balance and not self.overdraft_protection:
            raise ValueError(
                f"Cannot go below minimum balance of ${min_balance:.2f}"
            )

        self.balance -= amount
        self.daily_withdrawn += amount
        txn = Transaction(
            TransactionType.WITHDRAWAL,
            amount,
            from_account=self.account_number,
            description=description,
        )
        self.transactions.append(txn)
        return txn

    def apply_interest(self):
        if not self.is_active:
            return None
        rate = self.INTEREST_RATES[self.account_type]
        interest = self.balance * rate / 12
        if interest > 0:
            self.balance += interest
            txn = Transaction(
                TransactionType.INTEREST,
                interest,
                to_account=self.account_number,
                description=f"Monthly interest at {rate * 100:.2f}%",
            )
            self.transactions.append(txn)
            return txn
        return None

    def apply_monthly_fee(self):
        if not self.is_active:
            return None
        fee = self.MONTHLY_FEE[self.account_type]
        if fee > 0:
            self.balance -= fee
            txn = Transaction(
                TransactionType.FEE,
                fee,
                from_account=self.account_number,
                description="Monthly maintenance fee",
            )
            self.transactions.append(txn)
            return txn
        return None

    def enable_overdraft(self, limit=500.0):
        if self.account_type == AccountType.SAVINGS:
            raise ValueError("Overdraft not available for savings accounts")
        self.overdraft_protection = True
        self.overdraft_limit = limit

    def disable_overdraft(self):
        if self.balance < 0:
            raise ValueError("Clear negative balance before disabling overdraft")
        self.overdraft_protection = False
        self.overdraft_limit = 0.0

    def deactivate(self):
        if self.balance != 0:
            raise ValueError("Clear balance before deactivating account")
        self.is_active = False

    def reactivate(self):
        self.is_active = True

    def get_statement(self, days=30):
        cutoff = datetime.datetime.now() - datetime.timedelta(days=days)
        recent = [t for t in self.transactions if t.timestamp >= cutoff]
        return {
            "account_number": self.account_number,
            "owner": self.owner,
            "account_type": self.account_type.value,
            "current_balance": self.balance,
            "period_days": days,
            "transactions": [t.to_dict() for t in recent],
            "total_deposits": sum(
                t.amount for t in recent
                if t.transaction_type == TransactionType.DEPOSIT
            ),
            "total_withdrawals": sum(
                t.amount for t in recent
                if t.transaction_type == TransactionType.WITHDRAWAL
            ),
            "total_fees": sum(
                t.amount for t in recent
                if t.transaction_type == TransactionType.FEE
            ),
            "total_interest": sum(
                t.amount for t in recent
                if t.transaction_type == TransactionType.INTEREST
            ),
        }

    def __repr__(self):
        return (
            f"Account(number={self.account_number}, owner={self.owner}, "
            f"type={self.account_type.value}, balance=${self.balance:.2f})"
        )


class Customer:
    def __init__(self, first_name, last_name, email, phone="", address=""):
        self.id = self._generate_id()
        self.first_name = first_name
        self.last_name = last_name
        self.email = email
        self.phone = phone
        self.address = address
        self.accounts = []
        self.created_at = datetime.datetime.now()
        self.is_verified = False

    @staticmethod
    def _generate_id():
        return "CUS-" + "".join(random.choices(string.digits, k=8))

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}"

    def verify(self):
        self.is_verified = True

    def add_account(self, account):
        self.accounts.append(account)

    def get_total_balance(self):
        return sum(a.balance for a in self.accounts if a.is_active)

    def get_accounts_by_type(self, account_type):
        return [
            a for a in self.accounts
            if a.account_type == account_type and a.is_active
        ]

    def __repr__(self):
        return (
            f"Customer(id={self.id}, name={self.full_name}, "
            f"accounts={len(self.accounts)})"
        )


class LoanStatus(Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    ACTIVE = "active"
    PAID_OFF = "paid_off"
    DEFAULTED = "defaulted"


class Loan:
    def __init__(self, customer, amount, annual_rate, term_months):
        self.id = "LN-" + "".join(random.choices(string.digits, k=8))
        self.customer = customer
        self.principal = amount
        self.annual_rate = annual_rate
        self.term_months = term_months
        self.remaining_balance = amount
        self.monthly_payment = self._calculate_monthly_payment()
        self.payments_made = 0
        self.status = LoanStatus.PENDING
        self.created_at = datetime.datetime.now()
        self.payment_history = []

    def _calculate_monthly_payment(self):
        monthly_rate = self.annual_rate / 12
        if monthly_rate == 0:
            return self.principal / self.term_months
        payment = self.principal * (
            monthly_rate * (1 + monthly_rate) ** self.term_months
        ) / ((1 + monthly_rate) ** self.term_months - 1)
        return round(payment, 2)

    def approve(self):
        if self.status != LoanStatus.PENDING:
            raise ValueError(f"Cannot approve loan in {self.status.value} status")
        self.status = LoanStatus.APPROVED

    def activate(self):
        if self.status != LoanStatus.APPROVED:
            raise ValueError("Loan must be approved before activation")
        self.status = LoanStatus.ACTIVE

    def reject(self, reason=""):
        if self.status != LoanStatus.PENDING:
            raise ValueError(f"Cannot reject loan in {self.status.value} status")
        self.status = LoanStatus.REJECTED

    def make_payment(self, amount=None):
        if self.status != LoanStatus.ACTIVE:
            raise ValueError("Loan is not active")

        payment_amount = amount or self.monthly_payment
        if payment_amount <= 0:
            raise ValueError("Payment must be positive")

        monthly_rate = self.annual_rate / 12
        interest_portion = self.remaining_balance * monthly_rate
        principal_portion = payment_amount - interest_portion

        if principal_portion < 0:
            raise ValueError("Payment does not cover interest")

        self.remaining_balance -= principal_portion
        self.payments_made += 1

        record = {
            "payment_number": self.payments_made,
            "amount": payment_amount,
            "principal": principal_portion,
            "interest": interest_portion,
            "remaining_balance": max(0, self.remaining_balance),
            "timestamp": datetime.datetime.now().isoformat(),
        }
        self.payment_history.append(record)

        if self.remaining_balance <= 0.01:
            self.remaining_balance = 0
            self.status = LoanStatus.PAID_OFF

        return record

    def get_amortization_schedule(self):
        schedule = []
        balance = self.principal
        monthly_rate = self.annual_rate / 12

        for month in range(1, self.term_months + 1):
            interest = balance * monthly_rate
            principal = self.monthly_payment - interest
            balance -= principal

            if balance < 0:
                balance = 0

            schedule.append({
                "month": month,
                "payment": self.monthly_payment,
                "principal": round(principal, 2),
                "interest": round(interest, 2),
                "balance": round(balance, 2),
            })

        return schedule

    def __repr__(self):
        return (
            f"Loan(id={self.id}, customer={self.customer.full_name}, "
            f"principal=${self.principal:.2f}, status={self.status.value})"
        )


class Bank:
    def __init__(self, name, routing_number=""):
        self.name = name
        self.routing_number = routing_number or self._generate_routing()
        self.customers = {}
        self.accounts = {}
        self.loans = {}
        self.transfer_log = []
        self.created_at = datetime.datetime.now()

    @staticmethod
    def _generate_routing():
        return "".join(random.choices(string.digits, k=9))

    def register_customer(self, first_name, last_name, email,
                          phone="", address=""):
        for c in self.customers.values():
            if c.email == email:
                raise ValueError(f"Customer with email {email} already exists")

        customer = Customer(first_name, last_name, email, phone, address)
        self.customers[customer.id] = customer
        return customer

    def remove_customer(self, customer_id):
        customer = self.customers.get(customer_id)
        if not customer:
            raise ValueError("Customer not found")

        active = [a for a in customer.accounts if a.is_active]
        if active:
            raise ValueError("Close all accounts before removing customer")

        del self.customers[customer_id]
        return True

    def open_account(self, customer_id, account_type, initial_deposit=0.0):
        customer = self.customers.get(customer_id)
        if not customer:
            raise ValueError("Customer not found")

        min_deposit = Account.MINIMUM_BALANCE[account_type]
        if initial_deposit < min_deposit:
            raise ValueError(
                f"Minimum initial deposit for {account_type.value} "
                f"is ${min_deposit:.2f}"
            )

        account = Account(customer.full_name, account_type, initial_deposit)
        customer.add_account(account)
        self.accounts[account.account_number] = account
        return account

    def close_account(self, account_number):
        account = self.accounts.get(account_number)
        if not account:
            raise ValueError("Account not found")
        account.deactivate()
        return True

    def get_account(self, account_number):
        account = self.accounts.get(account_number)
        if not account:
            raise ValueError("Account not found")
        return account

    def transfer(self, from_account_number, to_account_number, amount,
                 description="Transfer"):
        if from_account_number == to_account_number:
            raise ValueError("Cannot transfer to the same account")
        if amount <= 0:
            raise ValueError("Transfer amount must be positive")

        from_account = self.get_account(from_account_number)
        to_account = self.get_account(to_account_number)

        if not from_account.is_active or not to_account.is_active:
            raise ValueError("Both accounts must be active")

        from_account._check_withdrawal_limit(amount)

        effective_balance = from_account._get_effective_balance()
        if amount > effective_balance:
            raise ValueError(
                f"Insufficient funds. Available: ${effective_balance:.2f}"
            )

        from_account.balance -= amount
        from_account.daily_withdrawn += amount
        to_account.balance += amount

        txn_out = Transaction(
            TransactionType.TRANSFER,
            amount,
            from_account=from_account_number,
            to_account=to_account_number,
            description=f"{description} to {to_account_number}",
        )
        txn_in = Transaction(
            TransactionType.TRANSFER,
            amount,
            from_account=from_account_number,
            to_account=to_account_number,
            description=f"{description} from {from_account_number}",
        )

        from_account.transactions.append(txn_out)
        to_account.transactions.append(txn_in)

        self.transfer_log.append({
            "from": from_account_number,
            "to": to_account_number,
            "amount": amount,
            "timestamp": datetime.datetime.now().isoformat(),
            "transaction_ids": [txn_out.id, txn_in.id],
        })

        return txn_out, txn_in

    def create_loan(self, customer_id, amount, annual_rate, term_months):
        customer = self.customers.get(customer_id)
        if not customer:
            raise ValueError("Customer not found")
        if amount <= 0:
            raise ValueError("Loan amount must be positive")
        if annual_rate < 0:
            raise ValueError("Interest rate cannot be negative")
        if term_months <= 0:
            raise ValueError("Loan term must be positive")

        loan = Loan(customer, amount, annual_rate, term_months)
        self.loans[loan.id] = loan
        return loan

    def process_loan_payment(self, loan_id, amount=None):
        loan = self.loans.get(loan_id)
        if not loan:
            raise ValueError("Loan not found")
        return loan.make_payment(amount)

    def apply_monthly_maintenance(self):
        results = {"interest_applied": [], "fees_charged": []}
        for account in self.accounts.values():
            if not account.is_active:
                continue
            interest_txn = account.apply_interest()
            if interest_txn:
                results["interest_applied"].append({
                    "account": account.account_number,
                    "amount": interest_txn.amount,
                })
            fee_txn = account.apply_monthly_fee()
            if fee_txn:
                results["fees_charged"].append({
                    "account": account.account_number,
                    "amount": fee_txn.amount,
                })
        return results

    def get_bank_totals(self):
        active = [a for a in self.accounts.values() if a.is_active]
        return {
            "total_customers": len(self.customers),
            "total_accounts": len(active),
            "total_deposits": sum(a.balance for a in active),
            "total_loans": len(self.loans),
            "outstanding_loan_balance": sum(
                l.remaining_balance for l in self.loans.values()
                if l.status == LoanStatus.ACTIVE
            ),
            "accounts_by_type": {
                t.value: len([a for a in active if a.account_type == t])
                for t in AccountType
            },
        }

    def find_customer_by_email(self, email):
        for customer in self.customers.values():
            if customer.email == email:
                return customer
        return None

    def find_customer_by_name(self, name):
        name_lower = name.lower()
        return [
            c for c in self.customers.values()
            if name_lower in c.full_name.lower()
        ]

    def get_high_value_accounts(self, threshold=10000.0):
        return [
            a for a in self.accounts.values()
            if a.is_active and a.balance >= threshold
        ]

    def get_overdue_loans(self):
        return [
            l for l in self.loans.values()
            if l.status == LoanStatus.ACTIVE
            and l.payments_made < l.term_months
        ]


class AuditLog:
    def __init__(self):
        self.entries = []

    def log(self, action, actor, details=""):
        entry = {
            "timestamp": datetime.datetime.now().isoformat(),
            "action": action,
            "actor": actor,
            "details": details,
        }
        self.entries.append(entry)
        return entry

    def get_entries(self, action=None, actor=None, limit=50):
        filtered = self.entries
        if action:
            filtered = [e for e in filtered if e["action"] == action]
        if actor:
            filtered = [e for e in filtered if e["actor"] == actor]
        return filtered[-limit:]

    def get_summary(self):
        actions = {}
        for entry in self.entries:
            action = entry["action"]
            actions[action] = actions.get(action, 0) + 1
        return {
            "total_entries": len(self.entries),
            "actions": actions,
        }


class BankingSystem:
    def __init__(self, bank_name="National Bank"):
        self.bank = Bank(bank_name)
        self.audit = AuditLog()

    def register_customer(self, first_name, last_name, email,
                          phone="", address=""):
        customer = self.bank.register_customer(
            first_name, last_name, email, phone, address
        )
        self.audit.log(
            "REGISTER_CUSTOMER", "SYSTEM",
            f"Registered {customer.full_name} ({customer.id})"
        )
        return customer

    def open_account(self, customer_id, account_type, initial_deposit=0.0):
        account = self.bank.open_account(
            customer_id, account_type, initial_deposit
        )
        self.audit.log(
            "OPEN_ACCOUNT", customer_id,
            f"Opened {account_type.value} account {account.account_number}"
        )
        return account

    def deposit(self, account_number, amount, description="Deposit"):
        account = self.bank.get_account(account_number)
        txn = account.deposit(amount, description)
        self.audit.log(
            "DEPOSIT", account_number,
            f"Deposited ${amount:.2f}"
        )
        return txn

    def withdraw(self, account_number, amount, description="Withdrawal"):
        account = self.bank.get_account(account_number)
        txn = account.withdraw(amount, description)
        self.audit.log(
            "WITHDRAWAL", account_number,
            f"Withdrew ${amount:.2f}"
        )
        return txn

    def transfer(self, from_account, to_account, amount, description="Transfer"):
        txns = self.bank.transfer(from_account, to_account, amount, description)
        self.audit.log(
            "TRANSFER", from_account,
            f"Transferred ${amount:.2f} to {to_account}"
        )
        return txns

    def apply_for_loan(self, customer_id, amount, rate, term_months):
        loan = self.bank.create_loan(customer_id, amount, rate, term_months)
        self.audit.log(
            "LOAN_APPLICATION", customer_id,
            f"Applied for ${amount:.2f} loan ({loan.id})"
        )
        return loan

    def approve_loan(self, loan_id):
        loan = self.bank.loans.get(loan_id)
        if not loan:
            raise ValueError("Loan not found")
        loan.approve()
        loan.activate()
        self.audit.log(
            "LOAN_APPROVED", loan_id,
            f"Approved and activated loan for {loan.customer.full_name}"
        )
        return loan

    def make_loan_payment(self, loan_id, amount=None):
        record = self.bank.process_loan_payment(loan_id, amount)
        self.audit.log(
            "LOAN_PAYMENT", loan_id,
            f"Payment #{record['payment_number']}: ${record['amount']:.2f}"
        )
        return record

    def run_monthly_cycle(self):
        results = self.bank.apply_monthly_maintenance()
        self.audit.log(
            "MONTHLY_CYCLE", "SYSTEM",
            f"Interest: {len(results['interest_applied'])}, "
            f"Fees: {len(results['fees_charged'])}"
        )
        return results

    def generate_report(self):
        totals = self.bank.get_bank_totals()
        audit_summary = self.audit.get_summary()
        return {
            "bank_name": self.bank.name,
            "routing_number": self.bank.routing_number,
            "report_date": datetime.datetime.now().isoformat(),
            "financials": totals,
            "audit_summary": audit_summary,
        }


def print_separator(title=""):
    print("\n" + "=" * 60)
    if title:
        print(f"  {title}")
        print("=" * 60)


def print_account_info(account):
    print(f"  Account: {account.account_number}")
    print(f"  Type:    {account.account_type.value}")
    print(f"  Owner:   {account.owner}")
    print(f"  Balance: ${account.balance:.2f}")
    print(f"  Active:  {account.is_active}")


def print_transaction(txn):
    print(f"  [{txn.id}] {txn.transaction_type.value}: "
          f"${txn.amount:.2f} - {txn.description} ({txn.status.value})")


def print_loan_info(loan):
    print(f"  Loan ID:         {loan.id}")
    print(f"  Customer:        {loan.customer.full_name}")
    print(f"  Principal:       ${loan.principal:.2f}")
    print(f"  Rate:            {loan.annual_rate * 100:.1f}%")
    print(f"  Term:            {loan.term_months} months")
    print(f"  Monthly Payment: ${loan.monthly_payment:.2f}")
    print(f"  Remaining:       ${loan.remaining_balance:.2f}")
    print(f"  Status:          {loan.status.value}")


def print_report(report):
    print(f"  Bank:             {report['bank_name']}")
    print(f"  Routing:          {report['routing_number']}")
    print(f"  Report Date:      {report['report_date'][:19]}")
    financials = report["financials"]
    print(f"  Total Customers:  {financials['total_customers']}")
    print(f"  Total Accounts:   {financials['total_accounts']}")
    print(f"  Total Deposits:   ${financials['total_deposits']:.2f}")
    print(f"  Total Loans:      {financials['total_loans']}")
    print(f"  Outstanding Loan: ${financials['outstanding_loan_balance']:.2f}")
    print("  Accounts by Type:")
    for acct_type, count in financials["accounts_by_type"].items():
        print(f"    {acct_type}: {count}")


def run_simulation():
    system = BankingSystem("First National Bank")

    print_separator("BANKING SYSTEM SIMULATION")
    print(f"  Bank: {system.bank.name}")
    print(f"  Routing: {system.bank.routing_number}")

    print_separator("1. REGISTERING CUSTOMERS")
    alice = system.register_customer(
        "Alice", "Johnson", "alice@example.com",
        "555-0101", "123 Main St"
    )
    print(f"  Registered: {alice.full_name} ({alice.id})")

    bob = system.register_customer(
        "Bob", "Smith", "bob@example.com",
        "555-0102", "456 Oak Ave"
    )
    print(f"  Registered: {bob.full_name} ({bob.id})")

    carol = system.register_customer(
        "Carol", "Williams", "carol@example.com",
        "555-0103", "789 Pine Rd"
    )
    print(f"  Registered: {carol.full_name} ({carol.id})")

    dave = system.register_customer(
        "Dave", "Brown", "dave@example.com",
        "555-0104", "321 Elm St"
    )
    print(f"  Registered: {dave.full_name} ({dave.id})")

    print_separator("2. OPENING ACCOUNTS")
    alice_checking = system.open_account(
        alice.id, AccountType.CHECKING, 5000.0
    )
    print_account_info(alice_checking)
    print()

    alice_savings = system.open_account(
        alice.id, AccountType.SAVINGS, 10000.0
    )
    print_account_info(alice_savings)
    print()

    bob_checking = system.open_account(
        bob.id, AccountType.CHECKING, 3000.0
    )
    print_account_info(bob_checking)
    print()

    bob_business = system.open_account(
        bob.id, AccountType.BUSINESS, 15000.0
    )
    print_account_info(bob_business)
    print()

    carol_savings = system.open_account(
        carol.id, AccountType.SAVINGS, 25000.0
    )
    print_account_info(carol_savings)
    print()

    dave_checking = system.open_account(
        dave.id, AccountType.CHECKING, 1000.0
    )
    print_account_info(dave_checking)

    print_separator("3. PERFORMING DEPOSITS")
    txn = system.deposit(alice_checking.account_number, 2500.0, "Salary")
    print_transaction(txn)

    txn = system.deposit(bob_business.account_number, 8000.0, "Client payment")
    print_transaction(txn)

    txn = system.deposit(carol_savings.account_number, 5000.0, "Bonus")
    print_transaction(txn)

    txn = system.deposit(dave_checking.account_number, 750.0, "Freelance work")
    print_transaction(txn)

    print_separator("4. PERFORMING WITHDRAWALS")
    txn = system.withdraw(alice_checking.account_number, 500.0, "Rent")
    print_transaction(txn)

    txn = system.withdraw(bob_business.account_number, 3000.0, "Equipment")
    print_transaction(txn)

    txn = system.withdraw(dave_checking.account_number, 200.0, "Groceries")
    print_transaction(txn)

    print_separator("5. TRANSFERS BETWEEN ACCOUNTS")
    txn_out, txn_in = system.transfer(
        alice_checking.account_number,
        alice_savings.account_number,
        1000.0,
        "Savings contribution"
    )
    print("  Outgoing:")
    print_transaction(txn_out)
    print("  Incoming:")
    print_transaction(txn_in)
    print()

    txn_out, txn_in = system.transfer(
        bob_business.account_number,
        bob_checking.account_number,
        2000.0,
        "Owner draw"
    )
    print("  Outgoing:")
    print_transaction(txn_out)
    print("  Incoming:")
    print_transaction(txn_in)
    print()

    txn_out, txn_in = system.transfer(
        carol_savings.account_number,
        dave_checking.account_number,
        500.0,
        "Gift"
    )
    print("  Outgoing:")
    print_transaction(txn_out)
    print("  Incoming:")
    print_transaction(txn_in)

    print_separator("6. OVERDRAFT PROTECTION")
    alice_checking.enable_overdraft(1000.0)
    print(f"  Enabled overdraft for Alice's checking "
          f"(limit: ${alice_checking.overdraft_limit:.2f})")

    print_separator("7. TESTING ERROR HANDLING")
    error_tests = [
        ("Duplicate email", lambda: system.register_customer(
            "Fake", "User", "alice@example.com")),
        ("Negative deposit", lambda: system.deposit(
            alice_checking.account_number, -100)),
        ("Insufficient funds", lambda: system.withdraw(
            dave_checking.account_number, 999999)),
        ("Self transfer", lambda: system.transfer(
            alice_checking.account_number,
            alice_checking.account_number, 100)),
    ]
    for name, test_fn in error_tests:
        try:
            test_fn()
            print(f"  {name}: No error (unexpected)")
        except ValueError as e:
            print(f"  {name}: Caught - {e}")

    print_separator("8. LOAN PROCESSING")
    alice_loan = system.apply_for_loan(alice.id, 20000.0, 0.05, 36)
    print("  Loan application:")
    print_loan_info(alice_loan)
    print()

    system.approve_loan(alice_loan.id)
    print(f"  Loan {alice_loan.id} approved and activated")
    print()

    bob_loan = system.apply_for_loan(bob.id, 50000.0, 0.04, 60)
    system.approve_loan(bob_loan.id)
    print(f"  Loan {bob_loan.id} approved for Bob")
    print()

    print("  Making 3 payments on Alice's loan:")
    for i in range(3):
        record = system.make_loan_payment(alice_loan.id)
        print(f"    Payment {record['payment_number']}: "
              f"${record['amount']:.2f} "
              f"(principal: ${record['principal']:.2f}, "
              f"interest: ${record['interest']:.2f}, "
              f"remaining: ${record['remaining_balance']:.2f})")

    print_separator("9. AMORTIZATION SCHEDULE (first 6 months)")
    schedule = alice_loan.get_amortization_schedule()
    print(f"  {'Month':<7} {'Payment':>10} {'Principal':>10} "
          f"{'Interest':>10} {'Balance':>12}")
    print(f"  {'-' * 49}")
    for entry in schedule[:6]:
        print(f"  {entry['month']:<7} ${entry['payment']:>9.2f} "
              f"${entry['principal']:>9.2f} ${entry['interest']:>9.2f} "
              f"${entry['balance']:>11.2f}")

    print_separator("10. MONTHLY MAINTENANCE CYCLE")
    results = system.run_monthly_cycle()
    print("  Interest applied:")
    for item in results["interest_applied"]:
        print(f"    Account {item['account']}: ${item['amount']:.4f}")
    print("  Fees charged:")
    for item in results["fees_charged"]:
        print(f"    Account {item['account']}: ${item['amount']:.2f}")

    print_separator("11. ACCOUNT STATEMENTS")
    statement = alice_checking.get_statement(days=30)
    print(f"  Account: {statement['account_number']}")
    print(f"  Type:    {statement['account_type']}")
    print(f"  Balance: ${statement['current_balance']:.2f}")
    print(f"  Deposits:    ${statement['total_deposits']:.2f}")
    print(f"  Withdrawals: ${statement['total_withdrawals']:.2f}")
    print(f"  Fees:        ${statement['total_fees']:.2f}")
    print(f"  Interest:    ${statement['total_interest']:.4f}")
    print(f"  Transactions: {len(statement['transactions'])}")

    print_separator("12. CUSTOMER SEARCH")
    found = system.bank.find_customer_by_email("bob@example.com")
    if found:
        print(f"  Found by email: {found.full_name} ({found.id})")
        print(f"  Total balance: ${found.get_total_balance():.2f}")

    matches = system.bank.find_customer_by_name("Williams")
    print(f"  Search 'Williams': {len(matches)} result(s)")
    for m in matches:
        print(f"    {m.full_name} - {m.email}")

    print_separator("13. HIGH-VALUE ACCOUNTS")
    high_value = system.bank.get_high_value_accounts(5000.0)
    print(f"  Accounts with balance >= $5,000: {len(high_value)}")
    for account in high_value:
        print(f"    {account.account_number} ({account.owner}): "
              f"${account.balance:.2f}")

    print_separator("14. CURRENT BALANCES")
    all_accounts = [
        ("Alice Checking", alice_checking),
        ("Alice Savings", alice_savings),
        ("Bob Checking", bob_checking),
        ("Bob Business", bob_business),
        ("Carol Savings", carol_savings),
        ("Dave Checking", dave_checking),
    ]
    for label, account in all_accounts:
        print(f"  {label:<20} ${account.balance:.2f}")

    print_separator("15. BANK REPORT")
    report = system.generate_report()
    print_report(report)

    print_separator("16. AUDIT LOG (last 10 entries)")
    recent_audit = system.audit.get_entries(limit=10)
    for entry in recent_audit:
        print(f"  [{entry['timestamp'][:19]}] {entry['action']}: "
              f"{entry['details']}")

    audit_summary = system.audit.get_summary()
    print(f"\n  Total audit entries: {audit_summary['total_entries']}")
    print("  Actions breakdown:")
    for action, count in sorted(audit_summary["actions"].items()):
        print(f"    {action}: {count}")

    print_separator("SIMULATION COMPLETE")
    print(f"  Total customers: {len(system.bank.customers)}")
    print(f"  Total accounts:  {len(system.bank.accounts)}")
    print(f"  Total loans:     {len(system.bank.loans)}")
    print(f"  Audit entries:   {len(system.audit.entries)}")
    print()


if __name__ == "__main__":
    run_simulation()
