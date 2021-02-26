#!/bin/bash

export SECRET_KEY_BASE=W68eso5YQOlbtvSNUR50N/HDWj6IaEhAwMR3LtzuBEQAefwYVbX84bvoTA7XtiGi
export MIX_ENV=prod
export PORT=4789

echo "Stopping old copy of app, if any..."

_build/prod/rel/bulls_mp/bin/bulls_mp stop || true

echo "Starting app..."  

_build/prod/rel/bulls_mp/bin/bulls_mp start
