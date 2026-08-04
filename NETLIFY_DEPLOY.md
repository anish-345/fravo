# Deploying Fravo Privacy Policy to Netlify

This document provides step-by-step instructions for deploying the privacy policy site to Netlify.

## Prerequisites

- Netlify CLI installed (`npm install -g netlify-cli`)
- You're logged in to Netlify (`netlify login`)

## Deployment Steps

### Option 1: One-Command Deploy (Recommended)

Run this command to create a new site and deploy:

```powershell
netlify deploy --create-site "fravo-privacy" --prod
```

When prompted:
1. **Site name**: `fravo-privacy` (or your preferred name)
2. **Folder to deploy**: `public`
3. **Configure as a single-page app?**: No
4. **Site settings saved**: Yes

This will:
- Create a new Netlify site
- Deploy your privacy policy
- Provide you with a unique URL (like `fravo-privacy.netlify.app`)

### Option 2: Interactive Deploy

If you prefer to go through the interactive setup:

```powershell
netlify deploy
```

When prompted:
1. Select **"Deploy preview to new site"** or **"Deploy to production"**
2. Set **"Folder to deploy"** to `public`
3. Configure as needed

### Option 3: Using Git (Continuous Deployment)

If you want automatic deployments from GitHub:

1. First, link your site to the git repository:

```powershell
netlify link
```

Then select:
- **"Use current git remote origin"**
- Choose your site from the list (create if new)

2. Enable continuous deployment in Netlify dashboard

3. Future commits to `main` will auto-deploy

## After Deployment

Your privacy policy will be accessible at:
- `https://fravo-privacy.netlify.app` (or your chosen name)

## Manual Configuration

To customize your site further:

1. Go to your site in Netlify dashboard
2. **Site settings** → **Change site name** to `fravo-privacy`
3. **Deploy settings** → **Build and deploy**:
   - Build command: `echo 'No build needed'`
   - Publish directory: `public`
4. **HTTPS** is enabled by default

## Testing the Deployment

After deployment, verify:
1. Visit your site URL
2. Check that the privacy policy displays correctly
3. Test on mobile devices (responsive design)
4. Verify all links work

## Updating the Privacy Policy

When you update `public/index.html`:

```powershell
netlify deploy --prod
```

This will redeploy with the new content.

## Custom Domain (Optional)

To add a custom domain:

1. In Netlify dashboard → **Domain settings**
2. Click **"Add domain"**
3. Choose either:
   - Your Netlify subdomain (already done)
   - A custom domain you own
4. Follow the DNS configuration instructions

## Troubleshooting

### "This folder isn't linked to a project yet"

Use `netlify deploy --create-site <SITE_NAME> --prod` to create and deploy in one go.

### "No matching project found"

This means the site doesn't exist on your Netlify account yet. Use `--create-site` to create it.

### Build errors

Ensure your `public/index.html` file exists and is valid HTML.

### "netlify: command not found"

Install Netlify CLI globally:
```powershell
npm install -g netlify-cli
```

## Files Created

- `public/index.html` - Privacy policy HTML page
- `netlify.toml` - Netlify configuration
- `NETLIFY_DEPLOY.md` - This guide

## Support

For issues:
- Netlify CLI docs: https://docs.netlify.com/cli/
- Netlify dashboard: https://app.netlify.com/
