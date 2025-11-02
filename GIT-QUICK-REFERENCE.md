# Git Quick Reference for Homelabs

## Daily Commands

### Check Status
```bash
git status                    # See what's changed
git status --ignored          # Include ignored files
git diff                      # See unstaged changes
git diff --staged             # See staged changes
```

### Add & Commit
```bash
git add <file>                # Stage specific file
git add *.sh                  # Stage all shell scripts
git add .                     # Stage all changes (careful!)
git commit -m "Message"       # Commit staged changes
git commit -am "Message"      # Stage & commit all tracked files
```

### View History
```bash
git log                       # View commit history
git log --oneline             # Compact view
git log --stat                # Show files changed
git log --graph --oneline     # Visual branch tree
git show <commit>             # Show commit details
```

### Undo Changes
```bash
git checkout -- <file>        # Discard unstaged changes
git reset HEAD <file>         # Unstage file
git reset --soft HEAD~1       # Undo last commit, keep changes
git reset --hard HEAD~1       # Undo last commit, discard changes
```

## Branch Operations

### Create & Switch Branches
```bash
git branch                    # List branches
git branch <name>             # Create branch
git checkout <name>           # Switch to branch
git checkout -b <name>        # Create & switch
git branch -d <name>          # Delete branch
```

### Merge & Rebase
```bash
git merge <branch>            # Merge branch into current
git rebase <branch>           # Rebase current onto branch
git rebase -i HEAD~3          # Interactive rebase last 3 commits
```

## Remote Operations

### Setup Remote
```bash
git remote add origin <url>   # Add remote
git remote -v                 # List remotes
git remote remove origin      # Remove remote
```

### Push & Pull
```bash
git push origin main          # Push to main branch
git push -u origin main       # Push & set upstream
git push --all                # Push all branches
git pull                      # Fetch & merge
git fetch                     # Fetch without merging
```

## .gitignore Commands

### Test .gitignore
```bash
# Check if file is ignored
git check-ignore -v <file>

# List all ignored files
git status --ignored

# See what would be added (dry run)
git add --dry-run .
```

### Force Add Ignored File
```bash
# Only if you're SURE it's safe!
git add -f <file>
```

### Stop Tracking File
```bash
# Remove from git but keep locally
git rm --cached <file>

# Remove directory
git rm -r --cached <directory>
```

## Security Checks

### Before Committing
```bash
# Review all changes
git diff --staged

# Check for secrets
grep -r "password" .
grep -r "api_key" .
grep -r "secret" .

# List files to be committed
git ls-files --stage | grep -v "100644"
```

### After Accidental Commit
```bash
# Remove file from last commit
git rm --cached <file>
git commit --amend -m "Remove sensitive file"

# If already pushed (DANGEROUS - coordinate with team!)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch <file>" \
  --prune-empty --tag-name-filter cat -- --all
```

## Common Scenarios

### Scenario 1: Update .gitignore
```bash
# Edit .gitignore
nano .gitignore

# Remove tracked files that should be ignored
git rm -r --cached .
git add .
git commit -m "Update .gitignore"
```

### Scenario 2: See What Changed
```bash
# Since last commit
git diff HEAD

# Between commits
git diff <commit1> <commit2>

# Specific file history
git log --follow -p -- <file>
```

### Scenario 3: Create Feature Branch
```bash
# Create branch for new feature
git checkout -b feature/new-monitoring

# Make changes and commit
git add .
git commit -m "Add new monitoring feature"

# Push branch
git push -u origin feature/new-monitoring

# Merge into main when ready
git checkout main
git merge feature/new-monitoring
```

### Scenario 4: Fix Commit Message
```bash
# Fix last commit message
git commit --amend -m "New message"

# If already pushed (use carefully!)
git push --force-with-lease origin main
```

## Homelabs Specific

### Safe Files to Commit
```bash
git add Vagrantfile
git add *.sh
git add *.md
git add .gitignore
```

### Files to NEVER Commit
```bash
# These should be in .gitignore
.vagrant/
.kube/config
kubeconfig*
*.tfstate
*.tfvars
id_rsa
*.pem
secrets.yaml
.env
```

### Update Scripts
```bash
# Edit a script
nano setup-cluster.sh

# Test it
./setup-cluster.sh

# Commit changes
git add setup-cluster.sh
git commit -m "Update cluster setup script"
git push
```

## Collaboration

### Clone Repository
```bash
# Clone your repo
git clone https://github.com/username/homelabs.git
cd homelabs

# Clone specific branch
git clone -b develop https://github.com/username/homelabs.git
```

### Pull Latest Changes
```bash
# Update from remote
git pull

# If you have local changes
git stash                     # Save local changes
git pull                      # Update
git stash pop                 # Restore local changes
```

### Create Pull Request Workflow
```bash
# 1. Create feature branch
git checkout -b feature/description

# 2. Make changes and commit
git add .
git commit -m "Description"

# 3. Push to remote
git push -u origin feature/description

# 4. Create pull request on GitHub/GitLab
# 5. After approval, merge and delete branch
git checkout main
git pull
git branch -d feature/description
```

## Configuration

### Set User Info
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### View Config
```bash
git config --list
git config user.name
git config user.email
```

### Useful Aliases
```bash
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'
git config --global alias.visual 'log --oneline --graph --all'
```

## Emergency Commands

### Abandon All Changes
```bash
# Discard ALL uncommitted changes
git reset --hard HEAD
git clean -fd

# Are you sure? This is irreversible!
```

### Recover Deleted Commit
```bash
# Find lost commit
git reflog

# Recover it
git checkout <commit-hash>
git checkout -b recovered-branch
```

### Remove Last Commit
```bash
# Keep changes
git reset --soft HEAD~1

# Discard changes
git reset --hard HEAD~1
```

## Best Practices

1. **Commit Often**: Small, focused commits are better
2. **Write Good Messages**: Clear, descriptive commit messages
3. **Review Before Push**: Always check `git diff --staged`
4. **Pull Before Push**: Stay up to date with remote
5. **Use Branches**: Don't work directly on main
6. **Never Force Push**: Unless you're alone and know what you're doing

## Learn More

- Official Git Documentation: https://git-scm.com/doc
- Pro Git Book (Free): https://git-scm.com/book
- GitHub Guides: https://guides.github.com/
- GitLab Docs: https://docs.gitlab.com/ee/gitlab-basics/

