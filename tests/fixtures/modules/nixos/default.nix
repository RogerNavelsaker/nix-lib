{ lib, ... }: { options.hostSpec = lib.mkOption { type = lib.types.attrsOf lib.types.anything; default = { }; }; }
