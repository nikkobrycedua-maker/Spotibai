
    (function () {
      var authContainer = document.getElementById('authContainer');
      var signupPanel = document.getElementById('signupPanel');
      var signinPanel = document.getElementById('signinPanel');
      var signupForm = document.getElementById('signupForm');
      var signinForm = document.getElementById('signinForm');
      var signupPassword = document.getElementById('signupPassword');
      var signinPassword = document.getElementById('signinPassword');
      var signupConfirmPassword = document.getElementById('signupConfirmPassword');
      var toggleSignupPassword = document.getElementById('toggleSignupPassword');
      var toggleSigninPassword = document.getElementById('login-eye-icon');
      var passwordRulesList = document.getElementById('passwordRules');
      var signupStatus = document.getElementById('signupStatus');
      var signinStatus = document.getElementById('signinStatus');

      function setMode(showSignin) {
        authContainer.classList.toggle('panel-active', showSignin);
        signupPanel.setAttribute('aria-hidden', String(showSignin));
        signinPanel.setAttribute('aria-hidden', String(!showSignin));
        signupPanel.toggleAttribute('inert', showSignin);
        signinPanel.toggleAttribute('inert', !showSignin);
        clearErrors(signupForm);
        clearErrors(signinForm);
        signupStatus.textContent = '';
        signinStatus.textContent = '';
      }

      document.getElementById('linkSignIn').addEventListener('click', function (event) {
        event.preventDefault();
        setMode(true);
      });

      document.getElementById('linkSignUp').addEventListener('click', function (event) {
        event.preventDefault();
        setMode(false);
      });

      function clearErrors(form) {
        form.querySelectorAll('.field-error').forEach(function (error) {
          error.textContent = '';
        });
        form.querySelectorAll('[aria-invalid="true"]').forEach(function (input) {
          input.removeAttribute('aria-invalid');
        });
      }

      function setError(input, message) {
        var error = document.getElementById(input.id + 'Error');
        input.setAttribute('aria-invalid', 'true');
        error.textContent = message;
      }

      function isValidEmail(value) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
      }

      function getPasswordRules(password) {
        return {
          length: password.length >= 8,
          numberOrSymbol: /[0-9!@#$%^&*(),.?":{}|<>]/.test(password),
          case: /[a-z]/.test(password) && /[A-Z]/.test(password)
        };
      }

      function setPasswordToggleIcon(toggle, showPassword) {
        toggle.setAttribute('aria-label', showPassword ? 'Hide password' : 'Show password');
        toggle.setAttribute('aria-pressed', String(showPassword));
        toggle.innerHTML = showPassword
          ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7Z"></path><circle cx="12" cy="12" r="3"></circle></svg>'
          : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 3l18 18"></path><path d="M10.6 10.6a2 2 0 0 0 2.8 2.8"></path><path d="M9.9 5.2A10.8 10.8 0 0 1 12 5c6.4 0 10 7 10 7a16 16 0 0 1-3.1 3.9"></path><path d="M6.2 6.2C3.5 8 2 12 2 12s3.6 7 10 7c1.4 0 2.6-.3 3.7-.8"></path></svg>';
      }

      function updatePasswordRules() {
        var rules = getPasswordRules(signupPassword.value);
        Object.keys(rules).forEach(function (ruleName) {
          document.querySelector('[data-rule="' + ruleName + '"]').classList.toggle('valid', rules[ruleName]);
        });
        if (rules.length && rules.numberOrSymbol && rules.case) {
          signupPassword.removeAttribute('aria-invalid');
          document.getElementById('signupPasswordError').textContent = '';
        }
      }

      function handleSignupPasswordInput() {
        var hasPassword = signupPassword.value.length > 0;
        toggleSignupPassword.classList.toggle('hidden', !hasPassword);
        passwordRulesList.classList.toggle('hidden', !hasPassword);

        if (hasPassword) {
          updatePasswordRules();
          setPasswordToggleIcon(toggleSignupPassword, signupPassword.type === 'text');
        } else {
          passwordRulesList.querySelectorAll('li').forEach(function (rule) {
            rule.classList.remove('valid');
          });
          signupPassword.type = 'password';
          setPasswordToggleIcon(toggleSignupPassword, false);
        }
      }

      function togglePasswordVisibility(input, toggle) {
        var showPassword = input.type === 'password';
        input.type = showPassword ? 'text' : 'password';
        setPasswordToggleIcon(toggle, showPassword);
      }

      toggleSignupPassword.addEventListener('click', function () {
        togglePasswordVisibility(signupPassword, toggleSignupPassword);
      });

      signinPassword.addEventListener('input', function () {
        var hasPassword = signinPassword.value.length > 0;
        toggleSigninPassword.classList.toggle('hidden', !hasPassword);
        if (!hasPassword) {
          signinPassword.type = 'password';
        }
        setPasswordToggleIcon(toggleSigninPassword, signinPassword.type === 'text');
      });

      toggleSigninPassword.addEventListener('click', function () {
        togglePasswordVisibility(signinPassword, toggleSigninPassword);
      });

      signinForm.addEventListener('reset', function () {
        toggleSigninPassword.classList.add('hidden');
        window.setTimeout(function () {
          signinPassword.type = 'password';
          setPasswordToggleIcon(toggleSigninPassword, false);
          toggleSigninPassword.classList.add('hidden');
        }, 0);
      });

      signupPassword.addEventListener('input', function () {
        handleSignupPasswordInput();
        if (signupConfirmPassword.value && signupConfirmPassword.value === signupPassword.value) {
          signupConfirmPassword.removeAttribute('aria-invalid');
          document.getElementById('signupConfirmPasswordError').textContent = '';
        }
        signupStatus.textContent = '';
      });

      signupForm.addEventListener('reset', function () {
        toggleSignupPassword.classList.add('hidden');
        passwordRulesList.classList.add('hidden');
        window.setTimeout(handleSignupPasswordInput, 0);
      });

      signupConfirmPassword.addEventListener('input', function () {
        signupStatus.textContent = '';
        if (signupConfirmPassword.value === signupPassword.value) {
          signupConfirmPassword.removeAttribute('aria-invalid');
          document.getElementById('signupConfirmPasswordError').textContent = '';
        }
      });

      signupForm.querySelectorAll('input').forEach(function (input) {
        input.addEventListener('input', function () {
          signupStatus.textContent = '';
          if (input !== signupPassword && input !== signupConfirmPassword) {
            input.removeAttribute('aria-invalid');
            document.getElementById(input.id + 'Error').textContent = '';
          }
        });
      });

      signupForm.addEventListener('submit', function (event) {
        event.preventDefault();
        clearErrors(signupForm);
        signupStatus.textContent = '';
        var valid = true;
        var name = document.getElementById('signupName');
        var email = document.getElementById('signupEmail');
        var confirmPassword = signupConfirmPassword;
        var passwordRules = getPasswordRules(signupPassword.value);

        if (!name.value.trim()) {
          setError(name, 'Please enter your name.');
          valid = false;
        }

        if (!email.value.trim()) {
          setError(email, 'Please enter your email address.');
          valid = false;
        } else if (!isValidEmail(email.value.trim())) {
          setError(email, 'Please enter a valid email address.');
          valid = false;
        }

        if (!signupPassword.value) {
          setError(signupPassword, 'Please enter a password.');
          valid = false;
        } else if (!passwordRules.length || !passwordRules.numberOrSymbol || !passwordRules.case) {
          setError(signupPassword, 'Your password must meet all three requirements.');
          valid = false;
        }

        if (!confirmPassword.value) {
          setError(confirmPassword, 'Please re-type your password.');
          valid = false;
        } else if (signupPassword.value !== confirmPassword.value) {
          setError(confirmPassword, 'Passwords do not match.');
          valid = false;
        }

        if (valid) {
          signupStatus.textContent = 'Your details are valid. Connect an authentication service to create the account.';
        }
      });

      signinForm.addEventListener('submit', function (event) {
        event.preventDefault();
        clearErrors(signinForm);
        signinStatus.textContent = '';
        var email = document.getElementById('signinEmail');
        var password = document.getElementById('signinPassword');
        var valid = true;

        if (!email.value.trim()) {
          setError(email, 'Please enter your email address.');
          valid = false;
        } else if (!isValidEmail(email.value.trim())) {
          setError(email, 'Please enter a valid email address.');
          valid = false;
        }

        if (!password.value) {
          setError(password, 'Please enter your password.');
          valid = false;
        }

        if (valid) {
          signinStatus.textContent = 'Connect an authentication service to sign in.';
        }
      });

      document.querySelectorAll('.social-button').forEach(function (button) {
        button.addEventListener('click', function () {
          var activeStatus = authContainer.classList.contains('panel-active') ? signinStatus : signupStatus;
          activeStatus.textContent = button.dataset.provider + ' authentication is not connected yet.';
        });
      });

      document.getElementById('forgotPassword').addEventListener('click', function (event) {
        event.preventDefault();
        signinStatus.textContent = 'Password recovery is not connected yet.';
      });
    })();
  