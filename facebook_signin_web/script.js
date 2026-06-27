// script.js — behaviour for the Facebook-style sign in page.
// This is a UI clone: no real authentication is performed.

(function () {
  "use strict";

  const form = document.getElementById("login-form");
  const emailInput = document.getElementById("email");
  const passwordInput = document.getElementById("password");
  const toggleBtn = document.getElementById("toggle-password");
  const errorEl = document.getElementById("error");
  const forgotLink = document.getElementById("forgot-link");
  const createBtn = document.getElementById("create-account");

  // Show / hide the password.
  toggleBtn.addEventListener("click", function () {
    const isHidden = passwordInput.type === "password";
    passwordInput.type = isHidden ? "text" : "password";
    toggleBtn.textContent = isHidden ? "Hide" : "Show";
    toggleBtn.setAttribute(
      "aria-label",
      isHidden ? "Hide password" : "Show password"
    );
  });

  // Handle the login submission.
  form.addEventListener("submit", function (event) {
    event.preventDefault();
    errorEl.textContent = "";

    const email = emailInput.value.trim();
    const password = passwordInput.value;

    if (!email) {
      errorEl.textContent = "Please enter your email address or phone number.";
      emailInput.focus();
      return;
    }

    if (!password) {
      errorEl.textContent = "Please enter your password.";
      passwordInput.focus();
      return;
    }

    // No backend — simulate a successful login.
    errorEl.style.color = "#42b72a";
    errorEl.textContent = "Logged in successfully (demo). Welcome, " + email + "!";
  });

  // Stubs for the secondary actions.
  forgotLink.addEventListener("click", function (event) {
    event.preventDefault();
    alert("Forgotten password is not implemented in this demo.");
  });

  createBtn.addEventListener("click", function () {
    alert("Create new account is not implemented in this demo.");
  });
})();
