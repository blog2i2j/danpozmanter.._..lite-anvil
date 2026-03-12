-- mod-version:4
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"

config.plugins.remotessh = common.merge({
  mount_root = USERDIR .. PATHSEP .. "remote-ssh",
  sshfs_binary = "sshfs",
  sshfs_options = {
    "reconnect",
    "ServerAliveInterval=15",
    "ServerAliveCountMax=3",
    "auto_cache",
    "follow_symlinks",
  },
  mount_timeout = 30,
  unmount_timeout = 15,
}, config.plugins.remotessh)

local mounts_by_spec = {}
local mounts_by_path = {}
local mount_counter = 0


local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end


local function parse_remote_spec(spec)
  spec = trim(spec)
  if spec == "" then
    return nil, "remote path is empty"
  end
  if not spec:match("^[^:]+:.+$") then
    return nil, "expected format user@host:/absolute/path"
  end
  return spec
end


local function sanitize_mount_name(spec)
  return spec:gsub("^ssh://", ""):gsub("[^%w%.%-]+", "_")
end


local function run_command(argv, timeout)
  local ok, proc = pcall(process.start, argv)
  if not ok then
    return nil, proc
  end

  local exit_code = proc:wait(timeout)
  local stdout = proc.stdout:read("all") or ""
  local stderr = proc.stderr:read("all") or ""
  if exit_code ~= 0 then
    return nil, trim(stderr ~= "" and stderr or stdout ~= "" and stdout or ("command failed: " .. table.concat(argv, " ")))
  end
  return stdout
end


local function ensure_mount_root()
  local ok, err, path = common.mkdirp(config.plugins.remotessh.mount_root)
  if err and err ~= "path exists" then
    return nil, string.format("%s: %s", err, path or config.plugins.remotessh.mount_root)
  end
  return true
end


local function make_mountpoint(spec)
  mount_counter = mount_counter + 1
  local dirname = string.format(
    "%s-%04d",
    sanitize_mount_name(spec),
    mount_counter
  )
  return config.plugins.remotessh.mount_root .. PATHSEP .. dirname
end


local function mount_remote(spec)
  if mounts_by_spec[spec] then
    return mounts_by_spec[spec]
  end

  local ok, err = ensure_mount_root()
  if not ok then
    return nil, err
  end

  local mountpoint = make_mountpoint(spec)
  local created, mkdir_err, mkdir_path = common.mkdirp(mountpoint)
  if mkdir_err and mkdir_err ~= "path exists" then
    return nil, string.format("%s: %s", mkdir_err, mkdir_path or mountpoint)
  end

  local argv = {
    config.plugins.remotessh.sshfs_binary,
    spec,
    mountpoint,
  }
  if #config.plugins.remotessh.sshfs_options > 0 then
    argv[#argv + 1] = "-o"
    argv[#argv + 1] = table.concat(config.plugins.remotessh.sshfs_options, ",")
  end

  local _, mount_err = run_command(argv, config.plugins.remotessh.mount_timeout)
  if mount_err then
    common.rm(mountpoint, false)
    return nil, mount_err
  end

  mounts_by_spec[spec] = mountpoint
  mounts_by_path[mountpoint] = spec
  return mountpoint
end


local function unmount_command(mountpoint)
  if PLATFORM == "Mac OS X" then
    return { "umount", mountpoint }
  end
  local fusermount3 = "/usr/bin/fusermount3"
  if system.get_file_info(fusermount3) then
    return { fusermount3, "-u", mountpoint }
  end
  local fusermount = "/usr/bin/fusermount"
  if system.get_file_info(fusermount) then
    return { fusermount, "-u", mountpoint }
  end
  return { "umount", mountpoint }
end


local function unmount_remote_path(mountpoint)
  local spec = mounts_by_path[mountpoint]
  if not spec then
    return true
  end

  local _, err = run_command(unmount_command(mountpoint), config.plugins.remotessh.unmount_timeout)
  if err then
    return nil, err
  end

  mounts_by_path[mountpoint] = nil
  mounts_by_spec[spec] = nil
  common.rm(mountpoint, false)
  return true
end


local function attach_remote_project(project, spec)
  project.name = spec
  project.remote_ssh_spec = spec
  return project
end


local function connect_remote_project(spec, add_only)
  core.add_thread(function()
    local mountpoint, err = mount_remote(spec)
    if not mountpoint then
      core.error("Remote SSH mount failed: %s", err)
      return
    end

    local project
    if add_only then
      project = core.add_project(mountpoint)
    else
      project = core.set_project(mountpoint)
      core.root_view:close_all_docviews()
    end
    attach_remote_project(project, spec)
    core.log("Mounted remote project %q", spec)
  end)
end


local old_add_project = core.add_project
function core.add_project(project)
  local added = old_add_project(project)
  local spec = mounts_by_path[added.path]
  if spec then
    attach_remote_project(added, spec)
  end
  return added
end


local old_set_project = core.set_project
function core.set_project(project)
  local set = old_set_project(project)
  local spec = mounts_by_path[set.path]
  if spec then
    attach_remote_project(set, spec)
  end
  return set
end


local old_remove_project = core.remove_project
function core.remove_project(project, force)
  local removed = old_remove_project(project, force)
  if removed and mounts_by_path[removed.path] then
    local ok, err = unmount_remote_path(removed.path)
    if not ok then
      core.warn("Remote SSH unmount failed for %q: %s", removed.remote_ssh_spec or removed.path, err)
    end
  end
  return removed
end


command.add(nil, {
  ["remote-ssh:open-project"] = function()
    core.command_view:enter("Remote SSH Project", {
      submit = function(text)
        local spec, err = parse_remote_spec(text)
        if not spec then
          core.error(err)
          return
        end
        connect_remote_project(spec, false)
      end
    })
  end,

  ["remote-ssh:add-project"] = function()
    core.command_view:enter("Add Remote SSH Project", {
      submit = function(text)
        local spec, err = parse_remote_spec(text)
        if not spec then
          core.error(err)
          return
        end
        connect_remote_project(spec, true)
      end
    })
  end,
})
