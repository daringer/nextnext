from pathlib import Path

from nextbox_daemon.config import log


class Partitions:
    def __init__(self):
        pass


    def get_device_model(self, block_dev):
        try:
            return (Path("/sys/block") / block_dev / "device/model") \
                .read_text("utf-8").strip()
        except FileNotFoundError:
            return "n/a"
        except Exception as e:
            log.error("could not get device model", exc_info=e)
            return None


    def is_mounted(self, part):
        with Path("/proc/mounts").open() as fd:
            for line in fd:
                if not line.startswith("/"):
                    continue
                if line.startswith(f"/dev/{part}"):
                    return line.split(" ", 2)[1]
        return False


    def get_parts(self, block_dev):
        labels = { path.resolve().name: path.name \
            for path in Path("/dev/disk/by-label/").iterdir() }

        dct = {}
        for path in Path("/dev/disk/by-path/").iterdir():
            part = path.resolve().name
            if part.startswith(block_dev) and part != block_dev:
                dct[part] = {
                    "label": labels.get(part),
                    "mounted": self.is_mounted(part)
                }
        return dct

    def get_block_device(self, block_dev):
        return {
            "name": block_dev, 
            "model": self.get_device_model(block_dev),
            "parts": self.get_parts(block_dev)
        }


    @property
    def block_devices(self):
        dct = {}
        for dev in Path("/sys/block").iterdir():
            dct[dev.name] = self.get_block_device(dev.name)
        return dct


if __name__ == "__main__":
    p = Partitions()
    print(p.block_devices)