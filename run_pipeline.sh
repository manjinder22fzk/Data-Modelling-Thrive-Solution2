#!/bin/bash

echo "🔵 Creating virtual environment..."
python -m venv venv

echo "🔵 Activating virtual environment..."
source venv/Scripts/activate

echo "🔵 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "✅ Virtual environment setup complete!"

echo "🔵 Adding all changes to Git..."
git add .

echo "🔵 Committing changes..."
git commit -m "Automated commit from setup_and_push.sh on $(date '+%Y-%m-%d %H:%M:%S')"

echo "🔵 Pushing changes to remote main branch..."
git push origin main

echo "✅ Code pushed to GitHub. CI/CD Pipeline will now trigger!"
