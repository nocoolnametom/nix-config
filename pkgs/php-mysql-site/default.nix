{
  lib,
  stdenv,
  fetchFromGitLab,
}:

# Builder function for simple read-only PHP/MySQL sites
{
  pname,
  version ? "2020-11-06",
  rev,
  hash,
  sqlRev,
  sqlHash,
  envPrefix,
  phpNamespace,
  dbNameDefault ? "ab22334_db2",
  dbUserDefault ? "root",
  dbPassDefault ? "",
  dbHostDefault ? "localhost",
  homepage,
  description ? "Read-only scripture browser backed by MySQL",
}:

let
  src = fetchFromGitLab {
    domain = "gitlab.com";
    owner = "nocoolnametom";
    repo = pname;
    inherit rev hash;
  };
  sqlSrc = fetchFromGitLab {
    domain = "gitlab.com";
    owner = "nocoolnametom";
    repo = pname;
    rev = sqlRev;
    hash = sqlHash;
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    dest=$out/share/${pname}
    mkdir -p "$dest/vendor"

    cp -r ${src}/public "$dest/public"
    cp -r ${src}/src "$dest/src"
    cp ${src}/composer.json ${src}/composer.lock "$dest/"
    cp ${sqlSrc}/data.sql "$dest/"
    cp ${sqlSrc}/permissions.sql "$dest/"

    cat > "$dest/vendor/autoload.php" <<'AUTOLOADPHP'
    <?php
    require_once __DIR__ . '/../src/Display.php';
    AUTOLOADPHP

    # Generate a router appropriate for each site
    if [ "${phpNamespace}" = "JournalOfDiscourses" ]; then
      cat > "$dest/router.php" <<'ROUTERPHP'
    <?php
    $uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/';

    if ($uri === '/' || $uri === "") {
        require __DIR__ . '/public/index.php';
        return true;
    }

    // /{volume} or /{volume}/{discourse}
    if (preg_match('#^/([0-9]+)(/([0-9]+))?$#', $uri, $m)) {
        $_GET['volume'] = (int)$m[1];
        if (isset($m[3]) && $m[3] !== "") {
            $_GET['discourse'] = (int)$m[3];
        }
        require __DIR__ . '/public/index.php';
        return true;
    }

    // /people or /Author_Name (underscored)
    if ($uri === '/people') {
        $_GET['author'] = 'people';
        require __DIR__ . '/public/index.php';
        return true;
    }
    if (preg_match('#^/([^/]+)$#', $uri, $m)) {
        $_GET['author'] = urldecode($m[1]);
        require __DIR__ . '/public/index.php';
        return true;
    }

    return false;
    ROUTERPHP
    elif [ "${phpNamespace}" = "MormonQuotes" ]; then
      cat > "$dest/router.php" <<'ROUTERPHP'
    <?php
    $uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/';

    if ($uri === '/' || $uri === "") {
        require __DIR__ . '/public/index.php';
        return true;
    }

    // Treat single path segment as search term (author or tag)
    if (preg_match('#^/([^/]+)$#', $uri, $m)) {
        $_GET['one'] = urldecode($m[1]);
        require __DIR__ . '/public/index.php';
        return true;
    }

    return false;
    ROUTERPHP
    else
      cat > "$dest/router.php" <<'ROUTERPHP'
    <?php
    $uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/';

    if ($uri === '/' || $uri === "") {
        require __DIR__ . '/public/index.php';
        return true;
    }

    // Default: /{book} or /{book}/{chapter}
    if (preg_match('#^/([^/]+)(/([0-9]+))?$#', $uri, $matches)) {
        $_GET['book'] = urldecode($matches[1]);
        if (isset($matches[3]) && $matches[3] !== "") {
            $_GET['chapter'] = $matches[3];
        }
        require __DIR__ . '/public/index.php';
        return true;
    }

    return false;
    ROUTERPHP
    fi

    substituteInPlace "$dest/public/index.php" \
      --replace-quiet "/* DBName: */ '${dbNameDefault}'," "/* DBName: */ (getenv('${envPrefix}_DB_NAME') ?: '${dbNameDefault}')," \
      --replace-quiet "/* User: */ '${dbUserDefault}'," "/* User: */ (getenv('${envPrefix}_DB_USER') ?: '${dbUserDefault}')," \
      --replace-quiet "/* Pass: */ '${dbPassDefault}'," "/* Pass: */ (getenv('${envPrefix}_DB_PASSWORD') ?: '${dbPassDefault}')," \
      --replace-quiet "/* Host: */ '${dbHostDefault}'" "/* Host: */ (getenv('${envPrefix}_DB_HOST') ?: '${dbHostDefault}')" \
      --replace-quiet "/* DBName: */ \"${dbNameDefault}\"," "/* DBName: */ (getenv('${envPrefix}_DB_NAME') ?: \"${dbNameDefault}\")," \
      --replace-quiet "/* User: */ \"${dbUserDefault}\"," "/* User: */ (getenv('${envPrefix}_DB_USER') ?: \"${dbUserDefault}\")," \
      --replace-quiet "/* Pass: */ \"${dbPassDefault}\"," "/* Pass: */ (getenv('${envPrefix}_DB_PASSWORD') ?: \"${dbPassDefault}\")," \
      --replace-quiet "/* Host: */ \"${dbHostDefault}\"" "/* Host: */ (getenv('${envPrefix}_DB_HOST') ?: \"${dbHostDefault}\")"

    runHook postInstall
  '';

  meta = with lib; {
    inherit description homepage;
    license = licenses.free; # Permissively licensed source code for serving public domain data
    platforms = platforms.unix;
    maintainers = [ ];
  };
}
