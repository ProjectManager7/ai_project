#!/bin/sh

# Script to generate Node-RED settings.js with dynamic password hash
set -e

# Default values
NODE_RED_PASSWORD=${NODE_RED_PASSWORD:-"default_password"}
SETTINGS_FILE="/data/settings.js"

echo "Generating Node-RED settings with password authentication..."

# Check if settings.js already exists
if [ -f "$SETTINGS_FILE" ]; then
    echo "Settings file already exists at $SETTINGS_FILE, skipping generation..."
    exit 0
fi

# Install bcrypt locally in /tmp if not exists
if [ ! -d "/tmp/node_modules/bcrypt" ]; then
    echo "Installing bcrypt locally..."
    cd /tmp
    npm install bcrypt --silent 2>&1 | grep -v "npm notice" || true
fi

# Generate bcrypt hash for password
echo "Generating password hash..."
HASH=$(node -e "
const bcrypt = require('/tmp/node_modules/bcrypt');
const password = process.env.NODE_RED_PASSWORD || 'default_password';
const hash = bcrypt.hashSync(password, 8);
console.log(hash);
")

echo "Password hash generated successfully"

# Create settings.js from template
cat > "$SETTINGS_FILE" << 'EOF'
/**
 * Node-RED Settings - Auto-generated
 * This file is generated automatically with authentication enabled
 */

module.exports = {
    // Flow File and User Directory Settings
    flowFile: 'flows.json',
    credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET || 'a-secret-key',
    flowFilePretty: true,
    userDir: '/data',
    
    // Enable authentication for admin interface
    adminAuth: {
        type: "credentials",
        users: [{
            username: "admin",
            password: "HASH_PLACEHOLDER",
            permissions: "*"
        }]
    },
    
    // HTTP settings
    uiPort: process.env.PORT || 1880,
    httpAdminRoot: '/',
    httpNodeRoot: '/',
    
    // Security settings
    requireHttps: false,
    httpNodeCors: {
        origin: "*",
        methods: "GET,PUT,POST,DELETE"
    },
    
    // Editor theme
    editorTheme: {
        projects: {
            enabled: true
        }
    },
    
    // Logging
    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    },
    
    // Function settings
    functionGlobalContext: {},
    
    // MQTT settings
    mqttReconnectTime: 15000,
    serialReconnectTime: 15000,
    
    // Debug settings
    debugMaxLength: 1000,
    debugUseColors: true
};
EOF

# Replace password hash placeholder (both occurrences)
sed -i "s|HASH_PLACEHOLDER|$HASH|g" "$SETTINGS_FILE"

echo "Node-RED settings.js generated successfully at $SETTINGS_FILE"
echo "Username: admin"
echo "Password: [from NODE_RED_PASSWORD environment variable]"