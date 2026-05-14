from os import path

from setuptools import setup

from omniscan import __version__

here = path.abspath(path.dirname(__file__))

install_requires = [
    'dataclasses;python_version<"3.7"',
    "colorama",
    "aiohttp>=3.5.0",
    "tqdm>=4.31.0",
    "sherlock-project>=0.15.0",
    "holehe>=1.8.0",
    "httpx>=0.24.0",
]

tests_requires = ["tox", "flake8"]

with open(path.join(here, "README.md"), encoding="utf-8") as f:
    long_description = f.read()

setup(
    name="omniscan",
    version=__version__,
    description="Username and email availability scanner with full-spectrum coverage. Combines accurate registration-API checks with Sherlock's 480+ site sweep.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/HubDamian95/omniscan",
    author="HubDamian95",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Framework :: AsyncIO",
        "Environment :: Console",
        "Operating System :: OS Independent",
        "Topic :: Utilities",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    keywords="email email-checker username username-checker social-media osint sherlock",
    packages=["omniscan"],
    python_requires=">=3.8",
    install_requires=install_requires,
    extras_require={"tests": install_requires + tests_requires},
    entry_points={"console_scripts": ["omniscan=omniscan.__main__:main"]},
)
