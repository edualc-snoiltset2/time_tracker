# Facebook Sign In — HTML/JS Clone

A standalone, dependency-free HTML/CSS/JavaScript clone of the Facebook
login page. This mirrors the Flutter `SignInScreen`
(`lib/screens/auth/sign_in_screen.dart`) as a plain web page.

## Files

| File | Purpose |
|------|---------|
| `index.html` | Page markup (hero + login card) |
| `styles.css` | Facebook-style layout and theming |
| `script.js` | Password show/hide, form validation, demo login |

## Running

No build step or server is required — just open `index.html` in a browser:

```bash
# from the repo root
open facebook_signin_web/index.html      # macOS
xdg-open facebook_signin_web/index.html  # Linux
```

Or serve the folder with any static server, e.g.:

```bash
python3 -m http.server --directory facebook_signin_web 8000
# then visit http://localhost:8000
```

## Notes

This is a **UI clone for demonstration only**. No real authentication is
performed and it is not affiliated with Meta or Facebook. Submitting the
form with both fields filled shows a simulated success message.
