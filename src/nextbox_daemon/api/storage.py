from flask import Blueprint
from pathlib import Path


from nextbox_daemon.command_runner import CommandRunner
from nextbox_daemon.utils import requires_auth, success, error, get_partitions
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


