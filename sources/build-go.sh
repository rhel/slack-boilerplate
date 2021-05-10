#!/bin/sh

image=golang:1
module="$1"

errx() {
  echo "$*"
  exit 1
}

if [ -z "$module" ]; then
  echo "Usage: $0 <module>"
  exit 1
fi

case "$(uname)" in
  Linux)
    ;;
  *)
    errx "ERROR: $(uname) is not supported OS."
    ;;
esac

SCRIPT_ROOT=$(dirname "$(readlink -f $0)")

docker run \
  --rm \
  --env GOCACHE=/tmp/.cache \
  --volume "$SCRIPT_ROOT/$module:/go/src/$module" \
  --user $(id -u):$(id -g) \
  --workdir "/go/src/$module" \
  $image /bin/sh -c "
    set -x \
    && go get \
    && go build -v -o $module
  "
