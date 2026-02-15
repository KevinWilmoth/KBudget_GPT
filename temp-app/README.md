# KBudget Temporary WIP App

A fun, 90s retro-themed "Work in Progress" page for the KBudget GPT project.

## Features

- 🎨 Authentic 90s web design with neon colors and animations
- 🌈 Animated gradient background
- ✨ Twinkling stars effect
- 📱 Fully responsive design
- 🔊 Interactive sound effects
- 🎮 Hidden Konami code easter egg
- 🎯 Zero external dependencies

## Quick Start

### Run Locally

```bash
# Start the server
node server.js

# Open in browser
# Visit http://localhost:8080
```

### Run with Docker

```bash
# Build the image
docker build -t kbudget-wip .

# Run the container
docker run -p 8080:8080 kbudget-wip

# Access at http://localhost:8080
```

## Deployment

See the [Deployment Guide](../infrastructure/arm-templates/temp-wip-app/README.md) for detailed instructions on deploying to Azure App Service.

### Quick Deploy to Azure

The easiest way is to use GitHub Actions:

1. Push changes to the `main` branch
2. The workflow will automatically deploy to Azure
3. Visit the deployment URL shown in the workflow summary

Or manually trigger deployment:

1. Go to GitHub Actions
2. Select "Deploy Temporary WIP App"
3. Click "Run workflow"
4. Select environment (dev/staging/prod)

## Files

- **index.html** - The retro WIP page with inline CSS and JavaScript
- **server.js** - Lightweight Node.js HTTP server
- **package.json** - Node.js package configuration
- **Dockerfile** - Container image for deployment
- **.dockerignore** - Files to exclude from Docker build

## Customization

The page is fully self-contained in `index.html`. To customize:

1. Edit the HTML content
2. Modify colors in the CSS section
3. Adjust animations and effects
4. Test locally with `node server.js`
5. Deploy changes to Azure

## Easter Eggs

Try these:

- **Konami Code**: Arrow keys sequence ⬆⬆⬇⬇⬅➡⬅➡BA
- **Visitor Counter**: Increments every 5 seconds
- **Sound Test Button**: Generates a retro beep sound

## Technology Stack

- **Frontend**: Pure HTML5, CSS3, JavaScript (no frameworks)
- **Backend**: Node.js HTTP server
- **Deployment**: Azure App Service (Linux)
- **CI/CD**: GitHub Actions

## Browser Compatibility

Works in all modern browsers:
- ✅ Chrome/Edge
- ✅ Firefox
- ✅ Safari
- ✅ Opera

## License

Part of the KBudget GPT project.
