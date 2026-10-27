const { spawnSync } = require('node:child_process');

const defines = [
  `--dart-define=SUPABASE_URL=${process.env.SUPABASE_URL || ''}`,
  `--dart-define=SUPABASE_ANON_KEY=${process.env.SUPABASE_ANON_KEY || ''}`,
  `--dart-define=GOOGLE_CLIENT_ID=${process.env.GOOGLE_CLIENT_ID || ''}`,
  `--dart-define=GOOGLE_SERVER_CLIENT_ID=${process.env.GOOGLE_SERVER_CLIENT_ID || ''}`,
  `--dart-define=WEB_APP_URL=${process.env.WEB_APP_URL || ''}`,
  '--dart-define=PAYMENTS_DEMO=true',
];

const result = spawnSync(
  'flutter',
  ['build', 'web', '--release', '--base-href=/', ...defines],
  { stdio: 'inherit' },
);

if (result.error) {
  console.error(`Could not start Flutter build: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
