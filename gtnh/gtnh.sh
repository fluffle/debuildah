#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"
. "./ae2webintegration/ae2_web_password"

VERSION="2.9.0-beta-1"
ZIP="GT_New_Horizons_${VERSION}_Server_Java_17-25.zip"
URL="https://downloads.gtnewhorizons.com/ServerPacks/betas/${ZIP}"

declare -a MOD_URLS=(
  "https://github.com/GTNewHorizons/worldedit-gtnh/releases/download/v0.0.9/worldedit-v0.0.9.jar"
  "https://github.com/GTNewHorizons/spark/releases/download/v0.0.16-pre/spark-forge1710-1.10-SNAPSHOT.jar"
  "https://github.com/kuba6000/AE2-Web-Integration/releases/download/1.0.3-GTNH-Native-Fluids-Support-forge-pre-1.7.10/ae2webintegration-1.0.3-GTNH-Native-Fluids-Support-forge-pre-1.7.10.jar"
  "https://github.com/GTNewHorizons/SharedProspecting/releases/download/2.0.5/sharedprospecting-2.0.5.jar"
  "https://github.com/GTNewHorizons/GTNH-Web-Map/releases/download/0.3.47/gtnh-web-map-0.3.47.jar"
  "https://github.com/GTNewHorizons/Foreman/releases/download/0.5.0/foreman-0.5.0.jar"
)

write_versions gtnh "${pkgs[@]}"
# Obvs nobody packages gtnh for debian
echo "gtnh=${VERSION}" >> gtnh.versions
check_versions gtnh || exit 0

if [ ! -f "${ZIP}" ]; then
  # they don't publish checksums, oh well
  wget -O "${ZIP}" "${URL}"
fi

get_mod() {
  local to="$1"
  local url="$2"
  local file="${url##*/}"
  echo "Downloading ${file}"
  wget -q -O "${to}/mods/${file}" "${url}"
}

install_files() {
  local to="${1}/srv/minecraft"
  # Create serving dir.
  install -o 65532 -g 65532 -m 0755 -d "${to}"
  install -o 65532 -g 65532 -m 0755 -d "${to}/backups"
  install -o 65532 -g 65532 -m 0755 -d "${to}/dynmap"
  install -o 65532 -g 65532 -m 0755 -d "${to}/visualprospecting"
  # Extract zip
  echo "Extracting GTNH..."
  unzip -q -d "${to}" "${ZIP}"
  # Get additional mods
  # Can't just wget from curseforge, bleh.
  install -o 65532 -g 65532 -m 0644 -t "${to}/mods" \
    mods/*.jar
  # Github hosted <3
  for url in "${MOD_URLS[@]}"; do
    get_mod "$to" "$url"
  done
}

modify_configs() {
  local to="${1}/srv/minecraft"
  # Copy configs.
  install -o 65532 -g 65532 -m 0644 -t "${to}" \
    configs/server.properties \
    configs/*.json

  for f in \
    aurora.cfg \
    serverutilities.cfg \
    server/players.txt \
    server/ranks.txt \
  ; do
    install -o 65532 -g 65532 -m 0644 "serverutilities/${f}" "${to}/serverutilities/${f}"
  done

  local cfg="${to}/config"

  # Thanks to https://www.youtube.com/watch?v=ZyK2cTrLFRg for all these!
  # Disable pollution
  sed -i '/Activate Pollution/s/true/false/' "${cfg}/GregTech/Pollution.cfg"
  # Disable underground dirt / gravel gen
  sed -i '/generateUndergroundDirtGen/s/true/false/' "${cfg}/GregTech/WorldGeneration.cfg"
  sed -i '/generateUndergroundGravelGen/s/true/false/' "${cfg}/GregTech/WorldGeneration.cfg"
  # Lootgames: disable game of light; 3:1 ratio minesweeper:sudoku
  install -o 65532 -g 65532 -m 0755 -d "${cfg}/lootgames/games"
  install -o 65532 -g 65532 -m 0644 -t "${cfg}/lootgames/games" \
    lootgames/*.cfg
  # Forestry: disable butterflies
  sed -i '/disable.butterfly/s/false/true/' "${cfg}/forestry/common.cfg"
  # EnderStorage: double-size chests <3
  sed -i '/item.storage-size/s/1/2/' "${cfg}/EnderStorage.cfg"
  # StructureLib: faster placing
  install -o 65532 -g 65532 -m 0644 -t "${cfg}" configs/structurelib.cfg
  # RWG: Disable underground lakes because uggghhh, OTOH enable large TC biomes.
  sed -i '/Generate Underground L/s/true/false/' "${cfg}/RWG.cfg"
  sed -i '/Generate large Thaumcraft biomes/s/false/true/' "${cfg}/RWG.cfg"
  # AE2 Web Integration
  install -o 65532 -g 65532 -m 0755 -d "${cfg}/ae2webintegration"
  install -o 65532 -g 65532 -m 0644 -t "${cfg}/ae2webintegration" \
    ae2webintegration/ae2webintegration.cfg \
    ae2webintegration/webdata.json
  sed -i "s/__PASSWORD__/${AE2_WEB_PASSWORD}/" \
    "${cfg}/ae2webintegration/ae2webintegration.cfg"

  # Accept EULA
  sed -i 's/false/true/' "${to}/eula.txt"

  # Make sure everything is owned by the right user.
  chown -R 65532:65532 "${to}"
}

# Create the output container image.
id="$(from_java nonroot)"
dir="$(buildah mount "$id")"

# Install dependency packages etc.
pushd "$dir"

busybox

install_pkgs "${pkgs[@]}"

popd

# Extract gtnh zip, grab extra mods, overwrite configs
install_files "$dir"
modify_configs "$dir"

# So many JVM args hooo-lyyy...
declare -a args=(
  "/usr/bin/java"
  "-Xms10g"
  "-Xmx10g"
  "-XX:+UseZGC"
  "-XX:+UseLargePages"
  "-XX:+UseTransparentHugePages"
  "-XX:+AlwaysPreTouch"
  "-XX:+UnlockExperimentalVMOptions"
  "-XX:+HeapDumpOnOutOfMemoryError"
  "-XX:GCTimeLimit=40"
  "-XX:GCHeapFreeLimit=20"
  "-XX:HeapDumpPath=/srv/minecraft/backups"
  "-XX:+UseGCOverheadLimit"
  # From here on is stuff from server's java9args.txt
  "-Dfml.readTimeout=180"
  "-Dfml.queryResult=confirm"
  "-Dfile.encoding=UTF-8"
  "-Djava.system.class.loader=com.gtnewhorizons.retrofuturabootstrap.RfbSystemClassLoader"
  "--add-opens"
  "java.base/java.io=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.lang.invoke=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.lang.ref=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.lang.reflect=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.lang=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.net.spi=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.net=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.nio.channels=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.nio.charset=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.nio.file=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.nio=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.text=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.time.chrono=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.time.format=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.time.temporal=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.time.zone=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.time=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.util.concurrent.atomic=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.util.concurrent.locks=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.util.jar=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.util.zip=ALL-UNNAMED"
  "--add-opens"
  "java.base/java.util=ALL-UNNAMED"
  "--add-opens"
  "java.base/jdk.internal.loader=ALL-UNNAMED"
  "--add-opens"
  "java.base/jdk.internal.misc=ALL-UNNAMED"
  "--add-opens"
  "java.base/jdk.internal.ref=ALL-UNNAMED"
  "--add-opens"
  "java.base/jdk.internal.reflect=ALL-UNNAMED"
  "--add-opens"
  "java.base/sun.nio.ch=ALL-UNNAMED"
  "--add-opens"
  "java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED"
  "--add-opens"
  "java.desktop/sun.awt.image=ALL-UNNAMED"
  "--add-opens"
  "java.desktop/sun.awt=ALL-UNNAMED"
  "--add-opens"
  "java.sql.rowset/javax.sql.rowset.serial=ALL-UNNAMED"
  "--add-opens"
  "jdk.dynalink/jdk.dynalink.beans=ALL-UNNAMED"
  "--add-opens"
  "jdk.naming.dns/com.sun.jndi.dns=ALL-UNNAMED,java.naming"
  # jar to run
  "-jar"
  "lwjgl3ify-forgePatches.jar"
  "nogui"
)

# PORTS:
# - 25565 / tcp : query
# - 25565 / udp : game
# - 25566 / tcp : dynmap HTTP
# - 25567 / tcp : AE2 web integration HTTP
buildah config \
  --entrypoint "$( entrypoint "${args[@]}" )" \
  --env "JAVA_HOME=/usr/lib/jvm/temurin-25-jre-amd64" \
  --port 25565/tcp \
  --port 25565/udp \
  --port 25566/tcp \
  --port 25567/tcp \
  --volume /srv/minecraft/world \
  --volume /srv/minecraft/backups \
  --volume /srv/minecraft/dynmap \
  --volume /srv/minecraft/visualprospecting \
  --workingdir /srv/minecraft \
  "$id"

commit "$id" "gtnh" "$VERSION"
