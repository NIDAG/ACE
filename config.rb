### ACE CONFIGURATION FILE ###

# Content directories (can be relative or absolute paths)
CONTENT_DIR = 'content' # Root content directory
TABLE_DIR = 'tables' # Highwire journals have tables in separate files

# MySQL adapter settings
DB_HOST = 'localhost'
DB_USERNAME = 'root'
DB_PASSWORD = ''
DB_DATABASE = 'dbname'

### OPTIONAL SETTINGS ###

# Verbose output?
VERBOSE = true

# Tag articles with all words encountered in text?
TAG_ARTICLES = true

# Try to estimate sample size based on key phrases in text?
ESTIMATE_SAMPLE_SIZE = true

# If true, will err on the side of caution and remove any suspicious-
# looking peaks (e.g., coordinates > 100, too many zeros, etc.).
# Otherwise, will keep peak but flag potential problems.
EXTRA_VALIDATION = true

# if true, will save all articles to DB, whether or not
# they have any associated foci. If false, will only save
# articles that have at least one extracted focus.
SAVE_ALL_ARTICLES = false

# Always retrieve and save metadata from PubMed?
SAVE_PUBMED_METADATA = true