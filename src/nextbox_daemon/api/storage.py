from flask import Blueprint
from pathlib import Path


from nextbox_daemon.command_runner import CommandRunner
from nextbox_daemon.utils import requires_auth, success, error
from nextbox_daemon.config import cfg, log
from nextbox_daemon.consts import *

storage_api = Blueprint('storage', __name__)


@storage_api.route("/storage")
@requires_auth
def storage():
    parts = get_partitions()
    return success(data=parts)


@storage_api.route("/storage/mount/<device>")
@storage_api.route("/storage/mount/<device>/<name>")
@requires_auth
def mount_storage(device, name=None):
    parts = get_partitions()

    if name is None:
        print (parts)
        for idx in range(1, 11):
            _name = f"extra-{idx}"
            mount_target = f"/media/{_name}"
            if mount_target not in parts["mounted"].values():
                name = _name
                print(name)
                break

        if name is None:
            return error("cannot determine mount target, too many mounts?")

    if ".." in device or "/" in device or name == "nextcloud":
        return error("invalid device")
    if ".." in name or "/" in name:
        return error("invalid name")

    mount_target = f"/media/{name}"
    mount_device = None
    for avail in parts["available"]:
        if Path(avail).name == device:
            mount_device = avail

    if not mount_device:
        return error("device to mount not found")

    if mount_device == parts["main"]:
        return error("will not mount main data partition")

    if mount_device in parts["mounted"]:
        return error("already mounted")

    if mount_target in parts["mounted"].values():
        return error(f"target {mount_target} has been already mounted")

    if not os.path.exists(mount_target):
        os.makedirs(mount_target)

    cr = CommandRunner([MOUNT_BIN, mount_device, mount_target], block=True)
    if cr.returncode == 0:
        return success("Mounting successful", data=cr.output)
    else:
        cr.log_output()
        return error("Failed mounting, check logs...")

@storage_api.route("/storage/umount/<name>")
@requires_auth
def umount_storage(name):
    if ".." in name or "/" in name or name == "nextcloud":
        return error("invalid name")

    mount_target = f"/media/{name}"
    parts = get_partitions()

    if name == "nextcloud":
        return error("will not umount main data partition")

    if mount_target not in parts["mounted"].values():
        return error("not mounted")

    cr = CommandRunner([UMOUNT_BIN, mount_target], block=True)
    return success("Unmounting successful", data=cr.output)

def check_for_backup_process():
    global backup_proc

    out = dict(cfg["config"])
    if backup_proc is None:
        out["running"] = False
        return out

    assert isinstance(backup_proc, CommandRunner)

    backup_proc.get_new_output()

    if backup_proc.finished:
        if backup_proc.returncode == 0:
            backup_proc.parsed["state"] = "finished"

            cfg["config"]["last_" + backup_proc.user_info] = backup_proc.started
            cfg.save()


            out["last_" + backup_proc.user_info] = backup_proc.started
            log.info("backup/restore process finished successfully")
        else:
            backup_proc.parsed["state"] = "failed: " + backup_proc.parsed.get("unable", "")
            if "target" in backup_proc.parsed:
                if os.path.exists(backup_proc.parsed["target"]):
                    shutil.rmtree(backup_proc.parsed["target"])
                log.error("backup/restore process failed, logging output: ")
                for line in backup_proc.output[-30:]:
                    log.error(line.replace("\n", ""))


    out.update(dict(backup_proc.parsed))
    out["returncode"] = backup_proc.returncode
    out["running"] = backup_proc.running
    out["what"] = backup_proc.user_info

    if backup_proc.finished:
        backup_proc = None

    return out

