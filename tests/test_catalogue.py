#!/usr/bin/env python3
"""Tests for the SureTune station catalogue.

The catalogue's one job that can silently break is ordering: the curated
ad-free stations have to stay ahead of the directory results, and they have
to stay ahead of them *in rank order*. A merge that reorders, or a
deduplication bug that lets a directory copy of Radio Paradise displace the
curated entry, is invisible on screen until someone plays the wrong station.

Run: python3 tests/test_catalogue.py
"""

import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CTL = os.path.join(ROOT, "suretune-ctl")
SEED = os.path.join(ROOT, "ad-free-stations.json")


def load_seed():
    with open(SEED, encoding="utf-8") as handle:
        return json.load(handle)


def load_ctl():
    """Import suretune-ctl as a module without running its daemon loop."""
    namespace = {"__name__": "suretune_ctl_under_test", "__file__": CTL}
    with open(CTL, encoding="utf-8") as handle:
        exec(compile(handle.read(), CTL, "exec"), namespace)
    return namespace


class CuratedSeedTests(unittest.TestCase):
    def setUp(self):
        self.data = load_seed()

    def test_seed_file_is_valid_json_with_stations(self):
        self.assertIn("stations", self.data)
        self.assertIsInstance(self.data["stations"], list)
        self.assertGreater(len(self.data["stations"]), 0)

    def test_every_station_has_a_name_url_and_https_scheme(self):
        for station in self.data["stations"]:
            self.assertTrue(station.get("name"), "a station has no name")
            url = station.get("url", "")
            self.assertTrue(url.startswith("https://"),
                            "%s is not https: %s" % (station.get("name"), url))
            self.assertNotIn(" ", url, "%s has a space in its url" % station.get("name"))

    def test_urls_are_unique(self):
        urls = [s["url"] for s in self.data["stations"]]
        self.assertEqual(len(urls), len(set(urls)), "a url appears twice")

    def test_ranks_are_unique_and_follow_file_order(self):
        ranks = [s["rank"] for s in self.data["stations"]]
        self.assertEqual(len(ranks), len(set(ranks)), "a rank appears twice")
        self.assertEqual(ranks, sorted(ranks),
                         "the file must be in rank order; it is the order the UI shows")

    def test_has_at_least_ten_stations(self):
        # The brief asked for ten; a seed list shorter than that is a
        # regression against the thing it was added to fix.
        self.assertGreaterEqual(len(self.data["stations"]), 10)


class CatalogueOrderTests(unittest.TestCase):
    def setUp(self):
        self.ns = load_ctl()
        self.Sources = self.ns["Sources"]

    def test_curated_rows_returns_every_seed_station(self):
        seed_count = len(load_seed()["stations"])
        self.assertEqual(len(self.Sources.curated_rows()), seed_count)

    def test_curated_rows_preserve_file_order(self):
        seed = load_seed()["stations"]
        rows = self.Sources.curated_rows()
        self.assertEqual([r["title"] for r in rows], [s["name"] for s in seed])

    def test_curated_rows_are_marked_as_curated(self):
        for row in self.Sources.curated_rows():
            self.assertEqual(row["source"], "curated")

    def test_genre_filter_selects_only_that_genre(self):
        rows = self.Sources.curated_rows("Ambient")
        self.assertTrue(rows, "Ambient is seeded, so the filter must match something")
        for row in rows:
            self.assertNotEqual(row["source"], "nonsense")
        # Every returned row must genuinely be tagged Ambient in the seed.
        seed = {s["name"]: s.get("genre", "") for s in load_seed()["stations"]}
        for row in rows:
            self.assertEqual(seed[row["title"]], "Ambient")

    def test_unknown_genre_returns_nothing_rather_than_everything(self):
        # A genre with no curated match must not silently fall back to the
        # whole list, or tapping a genre shows the same stations every time.
        self.assertEqual(self.Sources.curated_rows("Polka"), [])

    def test_missing_seed_file_degrades_to_empty_rather_than_raising(self):
        # A broken or absent seed file must not take the bar widget down.
        self.ns["CURATED_STATIONS"] = os.path.join(ROOT, "does-not-exist.json")
        self.assertEqual(self.Sources.curated_rows(), [])

    def test_malformed_seed_file_degrades_to_empty(self):
        broken = os.path.join(ROOT, ".test-broken-seed.json")
        with open(broken, "w", encoding="utf-8") as handle:
            handle.write("{not json")
        try:
            self.ns["CURATED_STATIONS"] = broken
            self.assertEqual(self.Sources.curated_rows(), [])
        finally:
            os.unlink(broken)


class BrowseMergeTests(unittest.TestCase):
    """browse() must lead with the curated list and dedupe the rest."""

    def setUp(self):
        self.ns = load_ctl()
        self.messages = []

        class FakeCliamp:
            def call(self, operation, params=None, wait=True):
                # No daemon in the test environment; the directory half of
                # the merge is simply absent, which is the harder case for
                # ordering because there is nothing to push the curated rows
                # down.
                return {"ok": False, "error": "no daemon"}

            def job_result(self, message):
                return message

        self.backend = self.ns["Backend"](FakeCliamp())
        self.backend.emit = self.messages.append
        self.backend.cmd_browse({})
        self.message = self.messages[-1]

    def test_browse_reports_a_curated_count(self):
        self.assertIn("curated", self.message["counts"])
        self.assertGreater(self.message["counts"]["curated"], 0)

    def test_curated_stations_come_first_and_in_order(self):
        seed = load_seed()["stations"]
        titles = [row["title"] for row in self.message["items"]]
        leading = titles[:len(seed)]
        self.assertEqual(leading, [s["name"] for s in seed],
                         "the curated list must lead the catalogue, in rank order")

    def test_no_duplicate_paths_in_the_merged_catalogue(self):
        paths = [row["path"] for row in self.message["items"]]
        self.assertEqual(len(paths), len(set(paths)),
                         "the same stream must not appear twice in the list")

    def test_every_row_has_a_playable_path(self):
        for row in self.message["items"]:
            self.assertTrue(row.get("path"), "a row has no path: %r" % row)


if __name__ == "__main__":
    unittest.main(verbosity=2)
