#!/usr/bin/env bash
set -euo pipefail

# 1) Remove the old UI folder, if present
rm -rf ui/

# 2) Create our new site structure
mkdir -p website/{assets/{css,js,images},pages}

# 3) Create a very basic stylesheet
cat > website/assets/css/main.css <<'EOF'
body {
  margin: 0;
  background: #0a0a0f;
  color: #eee;
  font-family: sans-serif;
}
img.hero {
  display: block;
  max-width: 100%;
  margin: 2rem auto;
}
.container {
  padding: 1rem;
}
h1, h2 {
  text-align: center;
}
img.side-by-side {
  width: 48%;
  margin: 1%;
}
EOF

# 4) Boilerplate for index.html (Welcome)
cat > website/pages/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MathGPT • Welcome</title>
  <link rel="stylesheet" href="../assets/css/main.css">
</head>
<body>
  <div class="container">
    <h1>Welcome to MathGPT</h1>
    <img class="hero" src="../assets/images/01-welcome.png" alt="Welcome to MathGPT">
  </div>
</body>
</html>
EOF

# 5) Boilerplate for features.html (Features Overview)
cat > website/pages/features.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MathGPT • Features</title>
  <link rel="stylesheet" href="../assets/css/main.css">
</head>
<body>
  <div class="container">
    <h1>Features Overview</h1>
    <img class="hero" src="../assets/images/02-features.png" alt="Features Overview">
  </div>
</body>
</html>
EOF

# 6) Boilerplate for finetuning.html (Fine-Tuning for Coding Tasks)
cat > website/pages/finetuning.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MathGPT • Fine-Tuning</title>
  <link rel="stylesheet" href="../assets/css/main.css">
</head>
<body>
  <div class="container">
    <h1>Fine-Tuning for Coding Tasks</h1>
    <img class="hero" src="../assets/images/03-finetune.png" alt="Fine-Tuning for Coding Tasks">
  </div>
</body>
</html>
EOF

# 7) Boilerplate for comparison.html (General vs Coding Assistant)
cat > website/pages/comparison.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MathGPT • Comparison</title>
  <link rel="stylesheet" href="../assets/css/main.css">
</head>
<body>
  <div class="container">
    <h1>General vs Coding Assistant</h1>
    <div style="text-align: center;">
      <img class="side-by-side" src="../assets/images/04-general-vs-coding.png" alt="General vs Coding Assistant">
      <img class="side-by-side" src="../assets/images/05-general-vs-coding-alt.png" alt="General vs Coding Assistant Alt">
    </div>
  </div>
</body>
</html>
EOF

echo "✅ Scaffolding complete!"
