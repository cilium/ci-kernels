#!/usr/bin/env python3
"""Fetch the releases listed on the kernel.org homepage and write versions.json."""

from typing import Any
import json
import os
import urllib.request
from dataclasses import dataclass

RELEASES_URL = "https://www.kernel.org/releases.json"
OCI_REPOSITORY = "ghcr.io/cilium/ci-kernels"

VERSIONS = "versions.json"
README = "README.md"
BEGIN_MARKER = "<!-- versions:begin -->"
END_MARKER = "<!-- versions:end -->"


@dataclass
class Release:
    version: str
    channel: str
    image_tag: str = ""

    @classmethod
    def from_json(cls, release):
        """Input releases.json looks as follows:
        {
            "releases": [ {
                "moniker": "mainline", "version": "7.3-rc4", ...
            } ... ]
        }
        """
        return cls(
            version=release["version"],
            channel=release["moniker"],
        )

    def sort_key(self):
        """Numeric version with the -rc suffix stripped; releases.json never
        contains multiple rc's of the same version."""
        version = self.version.split("-", 1)[0]
        return tuple(int(part) for part in version.split("."))

    def __lt__(self, other):
        return self.sort_key() < other.sort_key()

    def to_json(self):
        entry: dict[str, str] = {
            "version": self.version,
            "channel": self.channel,
        }

        if self.image_tag:
            entry["image_tag"] = self.image_tag

        return entry


def wanted(release):
    """No images are built for EOL kernels or linux-next."""
    return not release["iseol"] and release["moniker"] != "linux-next"


def render_table(releases):
    lines: list[str] = [
        "| Version | Channel | Image | Tag |",
        "|---|---|---|---|",
    ]

    for release in releases:
        lines.append(f"| {release.version} | {release.channel} | `{OCI_REPOSITORY}:{release.version}` | {release.image_tag} |")

    return "\n".join(lines)


def update_readme(releases: list[Release], filename: str):
    """Replace the contents between the version markers in README.md."""
    with open(filename) as f:
        readme: str = f.read()

    begin: int = readme.index(BEGIN_MARKER) + len(BEGIN_MARKER)
    end: int = readme.index(END_MARKER)

    with open(filename, "w") as f:
        f.write(readme[:begin] + "\n")
        f.write(render_table(releases) + "\n")
        f.write(readme[end:])

def from_json_sorted(raw: list[dict[str, Any]]) -> list[Release]:
    """Unmarshal a list of JSON releases and return them sorted in descending
    order by version."""
    return sorted((Release.from_json(r) for r in raw if wanted(r)), reverse=True)

def write_json(releases: list[Release], filename: str):
    """Write the list of releases to filename."""
    versions: list[dict[str, str]] = [r.to_json() for r in releases]

    with open(filename, "w") as f:
        json.dump(versions, f, indent=2)
        f.write("\n")


def tag_releases(releases: list[Release]) -> None:
    """Give the newest release in each channel a static image tag.

    Requires the input list to be sorted in descending order by version.
    """
    tagged: set[str] = set()
    for r in releases:
        if r.channel not in tagged:
            tagged.add(r.channel)
            r.image_tag = r.channel

def absolute(path: str) -> str:
    """Return the absolute path relative to the repository root."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", path)

def main():
    with urllib.request.urlopen(RELEASES_URL) as resp:
        raw = json.load(resp)["releases"]

    releases: list[Release] = from_json_sorted(raw)

    tag_releases(releases)

    write_json(releases, absolute(VERSIONS))

    update_readme(releases, absolute(README))

if __name__ == "__main__":
    main()
