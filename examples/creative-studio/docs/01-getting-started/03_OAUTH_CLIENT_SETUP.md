# OAuth Client ID Setup Guide

## Overview

This guide provides complete instructions for creating and configuring OAuth 2.0 credentials required for Google login in Creative Studio.

**What you'll create:**
- OAuth 2.0 Client ID (Web application type)
- Authorized JavaScript Origins for your frontend domains
- Firebase enabled with Google sign-in

**Time required:** ~15 minutes

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Create OAuth 2.0 Client ID](#create-oauth-20-client-id)
3. [Configure Authorized Origins](#configure-authorized-origins)
4. [Configure OAuth Consent Screen](#configure-oauth-consent-screen)
5. [Inject into Frontend](#inject-into-frontend)
6. [Verify Setup](#verify-setup)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, you must have:

- ✅ GCP Project created
- ✅ gcloud CLI authenticated
- ✅ Firebase project linked to your GCP project
- ✅ Your frontend deployment URLs (both for local and production)

**Verify prerequisites:**
```bash
# Check GCP project is set
gcloud config list | grep project

# Check Firebase is enabled
gcloud firebase projects describe YOUR_PROJECT_ID
```

---

## Create OAuth 2.0 Client ID

### Step 1: Enable Google+ API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services → Library**
4. Search for **Google+ API**
5. Click on it → Click **ENABLE**

### Step 2: Create OAuth Consent Screen

1. Go to **APIs & Services → OAuth consent screen**
2. Choose **User Type: External**
3. Click **CREATE**
4. Fill in:
   - **App name**: `Creative Studio`
   - **User support email**: Your email address
   - **Developer contact information**: Your email address
5. Click **SAVE AND CONTINUE**
6. On **Scopes** page: Click **SAVE AND CONTINUE** (no additional scopes needed)
7. On **Test users** page: Click **SAVE AND CONTINUE**
8. Review and click **BACK TO DASHBOARD**

### Step 3: Create Web Application Credentials

1. Go to **APIs & Services → Credentials**
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Choose **Application type: Web application**
4. Enter **Name**: `Creative Studio Frontend` (or your choice)
5. In **Authorized JavaScript origins**, add your frontend URLs:

   **For Local Development:**
   ```
   http://localhost:4200
   http://localhost:8080
   ```

   **For Production:**
   ```
   https://<your-firebase-project>.firebaseapp.com
   https://cstudio-frontend-production.web.app
   ```

   **For Staging (if applicable):**
   ```
   https://staging-cstudio.web.app
   ```

6. Leave **Authorized redirect URIs** empty (not needed for Google Identity Services)
7. Click **CREATE**

### Step 4: Copy Your Client ID

A dialog will appear with your credentials. **Copy the Client ID** - you'll need it immediately:

```
Client ID: <YOUR_CLIENT_ID>.apps.googleusercontent.com
Client secret: [you won't need this for frontend]
```

**⚠️ Important:** Store this Client ID securely. You'll use it in the next steps.

---

## Configure Authorized Origins

### Why This Matters

The OAuth Client validates that requests come from registered origins. Without your frontend domain registered, login will return **403 Forbidden**.

### The Allowed URLs List

For **Creative Studio**:

```
Development (Local):
  ✓ http://localhost:4200
  ✓ http://localhost:8080

Production:
  ✓ https://<your-firebase-project>.firebaseapp.com
  ✓ https://cstudio-frontend-production.web.app

Staging (optional):
  ✓ https://staging-cstudio.web.app
```

### Verify in Google Cloud Console

1. Go to **APIs & Services → Credentials**
2. Find your **Web application** credential
3. Click on it to edit
4. Scroll to **Authorized JavaScript origins**
5. Verify all your URLs are listed (without paths, just domain)

---

## Configure OAuth Consent Screen

### Make Consent Screen "Published"

The OAuth consent screen must be published for your app to work:

1. Go to **APIs & Services → OAuth consent screen**
2. Check the status at the top - should say **"PUBLISHED"**
3. If it says **"In development"**:
   - Click **PUBLISH APP**
   - Confirm the prompt
4. Status should now show **"PUBLISHED"**

### Why "External" Type?

- **External**: Allows any Google account to sign in (recommended for public apps)
- **Internal**: Only allows accounts in your Google Workspace organization

For Creative Studio, use **External** unless you're restricting to your company.

---

## Inject into Frontend

### For Cloud Build (Production)

The Client ID is injected automatically during Cloud Build:

1. **File**: `infra/modules/services/frontend/main.tf`
2. **The module passes**:
   ```hcl
   GOOGLE_CLIENT_ID = "from Secret Manager"
   ```

3. **Cloud Build replaces** in `frontend/src/environments/environment.prod.ts`:
   ```
   GOOGLE_CLIENT_ID_PLACEHOLDER → actual client ID
   ```

### For Local Development

Edit `frontend/src/environments/environment.ts`:

```typescript
export const environment = {
  // ... other config ...

  // Google OAuth - Get from Google Cloud Console
  GOOGLE_CLIENT_ID: '<YOUR_CLIENT_ID>.apps.googleusercontent.com',
};
```

### Verify Injection

After deployment, verify the Client ID was injected:

**In Browser Console:**
```javascript
console.log(environment.GOOGLE_CLIENT_ID)
// Should output: <YOUR_CLIENT_ID>.apps.googleusercontent.com
// Should NOT output: GOOGLE_CLIENT_ID_PLACEHOLDER
```

---

## Verify Setup

### Test 1: Check OAuth Console Configuration

```bash
gcloud oauth-configurations list \
  --project=YOUR_PROJECT_ID

# Should show your client ID with correct authorized origins
```

### Test 2: Test FedCM Request

The FedCM request is what was failing:

```bash
CLIENT_ID="<YOUR_CLIENT_ID>.apps.googleusercontent.com"
ORIGIN="https://<your-firebase-project>.firebaseapp.com"

curl "https://accounts.google.com/gsi/fedcm/clientmetadata?client_id=$CLIENT_ID" \
  -H "Accept: application/json" \
  -H "Origin: $ORIGIN" \
  -v

# Should return HTTP 200 (not 403)
# Response should contain: { "supported_endpoints": [...] }
```

### Test 3: Try Login in Browser

1. Open: `https://<your-firebase-project>.firebaseapp.com/login`
2. Click "Login with Google"
3. Should see One Tap UI or popup (not 403 error)
4. Should be able to sign in with your Google account

---

## Troubleshooting

### Issue: 403 Forbidden on FedCM Request

**Error**: `accounts.google.com/gsi/fedcm/clientmetadata?client_id=...` returns 403

**Cause**: The frontend domain is NOT in Authorized JavaScript Origins

**Fix**:
1. Go to **APIs & Services → Credentials**
2. Click on your Web application credential
3. Scroll to **Authorized JavaScript origins**
4. Add: `https://<your-firebase-project>.firebaseapp.com`
5. Click **SAVE**
6. Wait 5-10 minutes for propagation
7. Try login again

### Issue: "OAuth client ID missing" in Browser Console

**Error**: `OAuth client ID missing` when trying to initialize Google Identity Services

**Cause**: `GOOGLE_CLIENT_ID` is not injected or is `undefined` in `environment`

**Fix**:
1. Check browser console: `console.log(environment.GOOGLE_CLIENT_ID)`
2. If undefined:
   - Local dev: Edit `environment.ts` and add your Client ID
   - Production: Re-run Cloud Build (it will re-inject)
3. If it shows `GOOGLE_CLIENT_ID_PLACEHOLDER`:
   - Cloud Build injection failed
   - Check Cloud Build logs

### Issue: "OAuth client not found" Error

**Error**: Browser shows "OAuth client not found" or similar

**Cause**: Client ID is invalid or doesn't exist

**Fix**:
1. Go to **APIs & Services → Credentials**
2. Verify your Client ID is listed (Web application type)
3. Copy the exact Client ID from the console
4. Update your environment config with the correct ID
5. Re-deploy or refresh the page

### Issue: Login Popup Shows But Can't Complete Sign-In

**Cause**: Client is registered but OAuth Consent Screen is not published

**Fix**:
1. Go to **APIs & Services → OAuth consent screen**
2. Check status - should say **PUBLISHED**
3. If **In development**: Click **PUBLISH APP**
4. Try login again

### Issue: Domain Not Recognized (After Adding to Authorized Origins)

**Cause**: Changes haven't propagated yet

**Fix**:
1. Changes take 5-10 minutes to propagate
2. Clear browser cache (Ctrl+Shift+Delete)
3. Close and reopen the browser
4. Try login again after 10 minutes

---

## Security Checklist

✅ **Must Haves**:
- [ ] OAuth Consent Screen is **PUBLISHED** (not "In development")
- [ ] Authorized JavaScript Origins includes ONLY your domains (no wildcards)
- [ ] Authorized Redirect URIs is empty (not used by Google Identity Services)
- [ ] Client Secret is stored securely (never in frontend code or Git)
- [ ] HTTPS is enforced for production domains

✅ **Best Practices**:
- [ ] Client ID is injected by Cloud Build (not hardcoded)
- [ ] Separate Client IDs for dev and production (optional but recommended)
- [ ] GOOGLE_CLIENT_ID is validated to not be placeholder before deployment
- [ ] FedCM requests return 200 OK before enabling login

---

## Environment-Specific Configurations

### Development (localhost)

**Google Cloud Console:**
- Authorized JavaScript Origins:
  ```
  http://localhost:4200
  http://localhost:8080
  ```

**Frontend environment.ts:**
```typescript
GOOGLE_CLIENT_ID: '<YOUR_CLIENT_ID>.apps.googleusercontent.com'
```

**Start local dev:**
```bash
cd frontend
npm start
# App runs on http://localhost:4200
```

### Production

**Google Cloud Console:**
- Authorized JavaScript Origins:
  ```
  https://<your-firebase-project>.firebaseapp.com
  https://cstudio-frontend-production.web.app
  ```

**Cloud Build (automatic injection):**
- Secret Manager stores the Client ID
- Cloud Build injects it into `environment.prod.ts`

**After Terraform Apply:**
```bash
./scripts/inspect-deployment.sh frontend <your-environment>
# Verify GOOGLE_CLIENT_ID is injected correctly
```

---

## Related Documentation

- **Frontend Auth**: `docs/03-backend/03_AUTHENTICATION_FLOW.md`
- **Environment Variables**: `docs/01-getting-started/02_ENVIRONMENTS_SETUP.md`
- **Infrastructure Setup**: `infra/QUICK_START.md`
- **Login Troubleshooting**: `../../../OAUTH-CLIENT-FIX.md`
- **Login Analysis**: `../../../LOGIN-ANALYSIS.md`

---

## Quick Reference: All Authorized URLs

Copy-paste this list into **Authorized JavaScript Origins** in Google Cloud Console (replace placeholders with your actual URLs):

```
http://localhost:4200
http://localhost:8080
https://<your-firebase-project>.firebaseapp.com
https://cstudio-frontend-production.web.app
```

---

## Next Steps

1. ✅ Create OAuth Client ID (this guide)
2. ✅ Add Authorized Origins (this guide)
3. ✅ Publish OAuth Consent Screen (this guide)
4. ➡️ Configure Terraform with Client ID
5. ➡️ Deploy with Cloud Build
6. ➡️ Test login in browser

**Questions?** See: `OAUTH-CLIENT-FIX.md` or `LOGIN-ANALYSIS.md`
