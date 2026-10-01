"""Source-driven region/A* fixtures with independent geometry/cost oracles.

No compiler, AMXX VM, server physics or performance measurement is involved.
The strict test runtime interprets the selected Pawn control flow; graph,
array and collision operations are deterministic doubles.
"""
import copy
import heapq
import math
from pathlib import Path
import random
import unittest

from check_pawn_sources import include_directory
from pawn_test_runtime import PawnRuntime
from test_mapper_contracts import body, conditions, predicate


def includes():
    root = Path(__file__).resolve().parents[1]
    if not (root/'LOCAL.md').exists():
        raise unittest.SkipTest('External includes unavailable')
    return include_directory(root)


def common(runtime):
    for name, function in {
        'floatmin': min, 'floatmax': max, 'floatabs': abs, 'floatsqroot': math.sqrt,
        'float': float, 'min': min, 'max': max,
        'floatclamp': lambda v, lo, hi: max(lo, min(hi, v)),
        'anpc_distance_sq': lambda a, b: sum((x-y)**2 for x, y in zip(a, b)),
        'anpc_copy_vec': lambda a, b: b.__setitem__(slice(None), a[:]),
        'arrayset': lambda a, value, count: a.__setitem__(slice(0, count), [value]*count),
        'ArrayCreate': lambda *args: [], 'ArraySize': len,
        'ArrayClear': lambda a: a.clear(),
        'ArrayPushCell': lambda a, value: a.append(value), 'ArrayGetCell': lambda a, i: a[i],
        'ArrayGetArray': lambda a, i, out: out.__setitem__(slice(None), copy.deepcopy(a[i])),
        'ArraySetArray': lambda a, i, row: a.__setitem__(i, copy.deepcopy(row)),
        'ArrayPushArray': lambda a, row: a.append(copy.deepcopy(row)),
        'floatround': lambda n, mode: math.floor(n) if mode == 0 else math.ceil(n),
    }.items():
        runtime.bind(name, function)
    runtime.bind('ArrayDestroy', lambda handle: handle.put(0), (0,))


class SearchFixture:
    def __init__(self, origins, edges, starts, goals, crouch_terminal=(), directed=None):
        self.origins, self.edges, self.starts, self.goals = origins, edges, starts, goals
        self.from_point, self.goal_point = (0., 0., 0.), (100., 0., 0.)
        self.calls = []
        n = len(origins)
        self.values = {
            'ANPC_MAX_NODES': n, 'ANPC_SEARCH_JOBS': 1, 'ANPC_NEAR_CANDIDATES': 8,
            'ANPC_NODE_CROUCH': 1, 'ANPC_NODE_LADDER': 2, 'ANPC_CAP_CROUCH': 1, 'ANPC_CAP_LADDER': 4,
            'ANPC_PATH_NONE': 0, 'ANPC_PATH_PENDING': 1, 'ANPC_PATH_READY': 2, 'ANPC_PATH_FAILED': 3,
            'ANPC_NEIGHBOR_DONE': 0, 'ANPC_NEIGHBOR_EDGE': 1, 'ANPC_NEIGHBOR_PENDING': 2,
            'FM_StartFrame': 0, 'ANPC_MAX_ACTORS': 1,
            'gRouteOwner': [1], 'gRouteGeneration': [1], 'gNodeCount': n,
            'gRoutePosition': [True], 'gRouteCaps': [1], 'gRouteActor': [41], 'gRouteTarget': [7],
            'gRouteOrigin': [list(self.from_point)], 'gRouteDestination': [list(self.goal_point)],
            'gRouteStart': [starts[0]], 'gRouteGoal': [goals[0]],
            'gNodeOrigin': origins, 'gNodeFlags': [0]*n,
            'gRoutePath': [[]], 'gRoutePathRevision': [7], 'gRouteStatus': [1],
            'gJobRoute': [-1], 'gJobCurrent': [-1], 'gJobNeighborCursor': [0], 'gJobEpoch': [0],
            'gHeapSize': [0], 'gHeap': [[0]*n], 'gHeapPos': [[0]*n],
            'gStamp': [[0]*n], 'gClosed': [[0]*n], 'gParent': [[0]*n],
            'gCost': [[0.]*n], 'gPriority': [[0.]*n], 'gReversePath': [0]*n,
            'gJobAttachSide': [0], 'gJobAttachCursor': [0], 'gJobCandidateCount': [[0, 0]],
            'gJobCandidates': [[[0]*16, [0]*16]], 'gJobAnchorCount': [[0, 0]],
            'gJobAnchor': [[[0]*8, [0]*8]], 'gJobAnchorCost': [[[0.]*8, [0.]*8]],
            'gJobBestGoal': [-1], 'gJobBestCost': [1e20], 'gAttachBudget': 0, 'gFrameForward': 0,
        }
        runtime = self.runtime = PawnRuntime(self.values)
        common(runtime)

        def candidates(point, caps, out):
            selected = starts if tuple(point) == self.from_point else goals
            out[:len(selected)] = selected
            return len(selected)

        def walkable(a, b, duck, ignore):
            self.calls.append((tuple(a), tuple(b), bool(duck), ignore))
            if directed is not None and (tuple(a), tuple(b)) not in directed:
                return False
            if tuple(b) == self.goal_point and any(tuple(a) == tuple(origins[i]) for i in crouch_terminal):
                return duck
            return True

        def neighbor(node, cursor, destination, flags, cost, caps, now):
            outgoing = edges.get(node, ())
            index = cursor.get()
            if index == len(outgoing):
                return 0
            target, distance = outgoing[index]
            cursor.put(index+1); destination.put(target); flags.put(0); cost.put(distance)
            return 1

        runtime.bind('nav_position_candidates', candidates)
        runtime.bind('nav_walkable', walkable)
        runtime.bind('nav_next_neighbor', neighbor, (1, 2, 3, 4))
        runtime.bind('nav_edit_allowed', lambda plugin: True)
        runtime.bind('anpc_finite', lambda value: math.isfinite(value))
        runtime.bind('register_forward', lambda *args: 1)
        runtime.load((includes()/'navigation_search.inc').read_text(encoding='utf-8-sig'), (
            'nav_route_index', 'nav_stop_search', 'nav_cancel_route', 'native_request', 'native_request_to',
            'native_path_size', 'native_path_node', 'native_path_revision',
            'nav_heap_up', 'nav_heap_pop', 'nav_start_job', 'nav_job_heuristic',
            'nav_seed_job', 'nav_attach_job', 'nav_expand_job', 'nav_finish_job'))

    def solve(self):
        self.runtime.call('nav_start_job', 0, 0)
        for frame in range(500):
            self.values['gAttachBudget'] = 4
            for _ in range(32):
                if self.values['gJobRoute'][0] < 0:
                    return self.values['gRoutePath'][0]
                self.runtime.call('nav_expand_job', 0, float(frame))
        raise AssertionError('Source search failed to finish')

    def oracle(self, terminal_duck=()):
        # Exhaustive Dijkstra distances, independent of A* heuristics/stopping.
        costs, queue = {}, []
        for start in self.starts:
            costs[start] = math.dist(self.from_point, self.origins[start])
            heapq.heappush(queue, (costs[start], start))
        while queue:
            cost, node = heapq.heappop(queue)
            if cost != costs[node]:
                continue
            for target, distance in self.edges.get(node, ()):
                new = cost+distance
                if new < costs.get(target, math.inf):
                    costs[target] = new
                    heapq.heappush(queue, (new, target))
        return min((costs.get(goal, math.inf)+math.dist(self.origins[goal], self.goal_point)*(1.2 if goal in terminal_duck else 1.), goal)
                   for goal in self.goals)


class PositionRouteTests(unittest.TestCase):
    def test_actual_astar_cost_matches_independent_dijkstra_on_directed_graphs(self):
        rng = random.Random(61509)
        for sample in range(30):
            origins = [(rng.uniform(-100., 200.), rng.uniform(-100., 200.), 0.) for _ in range(10)]
            edges = {i: [(j, math.dist(origins[i], origins[j])*rng.uniform(1., 2.))
                         for j in range(10) if i != j and rng.random() < 0.2] for i in range(10)}
            fixture = SearchFixture(origins, edges, rng.sample(range(10), 3), rng.sample(range(10), 3))
            with self.subTest(sample=sample):
                path = fixture.solve()
                expected, goal = fixture.oracle()
                if math.isinf(expected):
                    self.assertEqual(fixture.values['gRouteStatus'][0], 3)
                    continue
                actual = math.dist(fixture.from_point, origins[path[0]])+math.dist(origins[path[-1]], fixture.goal_point)
                actual += sum(dict(edges[a])[b] for a, b in zip(path, path[1:]))
                self.assertAlmostEqual(actual, expected)

    def test_attachment_queries_obey_the_shared_frame_limit(self):
        fixture = SearchFixture([(float(i*6), 0., 0.) for i in range(16)], {}, list(range(8)), list(range(8, 16)))
        fixture.runtime.call('nav_start_job', 0, 0)
        fixture.values['gAttachBudget'] = 4
        for _ in range(32):
            fixture.runtime.call('nav_expand_job', 0, 0.)
        self.assertEqual(len(fixture.calls), 4)
        self.assertEqual(fixture.values['gJobAnchorCount'][0], [4, 0])

    def test_farther_start_anchor_avoids_nearest_anchor_detour(self):
        origins = [(4., 0., 0.), (20., 0., 0.), (94., 0., 0.), (4., 400., 0.)]
        fixture = SearchFixture(origins, {0: [(3, 400.)], 3: [(2, 410.)], 1: [(2, 74.)]}, [0, 1], [2])
        self.assertEqual(fixture.solve(), [1, 2])
        self.assertAlmostEqual(fixture.oracle()[0], 100.)

    def test_first_terminal_is_not_optimal_when_final_connector_requires_duck(self):
        fixture = SearchFixture([(0., 0., 0.), (90., 0., 0.), (80., 0., 0.)],
                                {0: [(1, 90.), (2, 81.)]}, [0], [1, 2], crouch_terminal=(1,))
        self.assertEqual(fixture.solve(), [0, 2])
        self.assertEqual(fixture.oracle(terminal_duck=(1,)), (101., 2))

    def test_goal_connector_is_checked_toward_player_on_one_way_floor(self):
        origins = [(0., 0., 0.), (90., 0., 0.)]
        allowed = {(origins[0], origins[0]), (origins[1], (100., 0., 0.))}
        fixture = SearchFixture(origins, {0: [(1, 90.)]}, [0], [1], directed=allowed)
        self.assertEqual(fixture.solve(), [0, 1])
        self.assertIn((origins[1], fixture.goal_point, False, 7), fixture.calls)

    def test_disconnected_nearest_goal_does_not_hide_reachable_alternative(self):
        fixture = SearchFixture([(0., 0., 0.), (99., 0., 0.), (90., 0., 0.)],
                                {0: [(2, 90.)]}, [0], [1, 2])
        self.assertEqual(fixture.solve(), [0, 2])

    def test_blocked_attachment_fails_without_creating_an_edge(self):
        fixture = SearchFixture([(0., 0., 0.), (90., 0., 0.)], {0: [(1, 90.)]}, [0], [1], directed=set())
        self.assertEqual(fixture.solve(), [])
        self.assertEqual(fixture.values['gRouteStatus'][0], 3)

    def test_same_anchor_can_finish_a_multi_source_route(self):
        fixture = SearchFixture([(90., 0., 0.)], {}, [0], [0])
        self.assertEqual(fixture.solve(), [0])

    def test_ladder_attachments_require_capability_same_volume_and_clear_hull(self):
        for caps, same_ladder, hull_clear, expected in ((4, True, True, 2), (1, True, True, 3),
                                                       (4, False, True, 3), (4, True, False, 3)):
            fixture = SearchFixture([(0., 0., 0.), (90., 0., 40.)], {0: [(1, 110.)]}, [0], [1], directed=set())
            fixture.values['gNodeFlags'][:] = [2, 2]
            fixture.values['gRouteCaps'][0] = caps
            fixture.runtime.bind('nav_ladder_at', lambda point: 2 if tuple(point) == fixture.goal_point and not same_ladder else 1)
            fixture.runtime.bind('nav_hull_clear', lambda *args: hull_clear)
            fixture.solve()
            with self.subTest(caps=caps, same=same_ladder, hull=hull_clear):
                self.assertEqual(fixture.values['gRouteStatus'][0], expected)

    def test_node_request_clears_position_mode_and_published_path(self):
        fixture = SearchFixture([(0., 0., 0.), (90., 0., 0.)], {0: [(1, 90.)]}, [0], [1])
        fixture.values['gRoutePath'][0] = [1]
        fixture.runtime.bind('get_param', lambda index: {1: 65, 2: 0, 3: 1, 4: 1}[index])
        fixture.runtime.bind('nav_allowed', lambda node, caps: node in (0, 1))
        self.assertTrue(fixture.runtime.call('native_request', 0))
        self.assertFalse(fixture.values['gRoutePosition'][0])
        self.assertEqual(fixture.values['gRoutePath'][0], [])
        self.assertEqual(fixture.solve(), [0, 1])
        self.assertEqual(fixture.values['gCost'][0][1], 90.)

    def test_replanning_keeps_published_path_until_atomic_replacement(self):
        fixture = SearchFixture([(0., 0., 0.), (90., 0., 0.)], {0: [(1, 90.)]}, [0], [1])
        values, runtime = fixture.values, fixture.runtime
        values['gRoutePath'][0] = [1]
        values['gRouteStatus'][0] = 2
        arguments = {1: 65, 2: 0, 4: 1, 5: 41, 6: 7}
        points = {2: [0., 0., 0.], 3: [100., 0., 0.]}
        runtime.bind('get_param', lambda index: arguments[index])
        runtime.bind('get_array_f', lambda index, out, count: out.__setitem__(slice(None), points[index][:count]))
        self.assertTrue(runtime.call('native_request_to', 0))
        self.assertEqual(values['gRouteStatus'][0], 1)
        self.assertEqual(runtime.call('native_path_size', 0), 1)
        self.assertEqual(runtime.call('native_path_node', 0), 1)
        self.assertEqual(runtime.call('native_path_revision', 0), 7)
        self.assertEqual(fixture.solve(), [0, 1])
        self.assertEqual(runtime.call('native_path_revision', 0), 8)


class RegionFixture:
    def __init__(self, points, edges=(), areas=None, flags=None, protected=(), capacity=32, hash_function=None):
        self.values = values = {
            'ANPC_MAX_NODES': capacity, 'ANPC_MAX_ACTORS': 1, 'NAV_NODE_AREAS': 8,
            'ANPC_NODE_CROUCH': 1, 'ANPC_NODE_LADDER': 2, 'ANPC_NODE_DISABLED': 4, 'ANPC_NODE_PORTAL': 8,
            'ANPC_CAP_CROUCH': 1, 'ANPC_CAP_ALL': 31, 'ANPC_LINK_JUMP': 1, 'floatround_floor': 0, 'floatround_ceil': 1,
            'NavRegionEdge': 14, 'NavLink': 7, 'NavRegionPortal': 5,
            'RP_ORIGINAL': 0, 'RP_FLAGS': 1, 'RP_FEET': slice(2, 5),
            'NL_TO': 0, 'NL_FLAGS': 1, 'NL_VELOCITY': slice(2, 5),
            'RE_FROM': 0, 'RE_TO': 1, 'RE_FLAGS': 2, 'RE_VELOCITY': slice(3, 6),
            'RE_FROM_FEET': slice(6, 9), 'RE_TO_FEET': slice(9, 12), 'RE_FROM_FLAGS': 12, 'RE_TO_FLAGS': 13,
            'gNodeCount': len(points), 'gNodeOrigin': [list(p) for p in points]+[[0., 0., 0.] for _ in range(capacity-len(points))],
            'gNodeFlags': list(flags or [0]*len(points))+[0]*(capacity-len(points)), 'gNodeRadius': [8.]*capacity,
            'gNodeLinks': [0]*capacity, 'gLinkCount': [0]*capacity,
            'gBucketHead': [-1]*64, 'gBucketNext': [-1]*capacity,
            'gRegionTransitions': 0, 'gRegionPhase': 0, 'gRegionOriginal': 0, 'gRegionCursor': 0,
            'gRegionPortalPlan': 0, 'gRegionPortalNeeded': 0,
            'gRegionLink': 0, 'gRegionKept': 0, 'gRegionNeeded': 0, 'gRegionPortals': 0,
            'gRegionEdges': 0, 'gRegionPortalLimit': 0, 'gRegionsReady': False,
            'gRegionKeep': [False]*capacity, 'gRegionMap': [-1]*capacity, 'gPairBlockedFrom': [-1]*16,
            'gRegionBucket': 0, 'gRegionNeighbor': -2, 'gAreaNodeHead': [-1]*8,
        }
        areas = areas or [(0., 0., 256., 128., 0., (0., 0., 1.))]
        values.update(gAreaCount=len(areas), gAreaMins=[[a[0], a[1], a[4]] for a in areas],
                      gAreaMaxs=[[a[2], a[3], a[4]] for a in areas], gAreaNormal=[list(a[5]) for a in areas],
                      gAreaFlags=[0]*len(areas), gAreaHead=[-1]*64, gAreaNext=[-1]*len(areas),
                      gRegionParent=[[0]*len(areas), [0]*len(areas)])
        runtime = self.runtime = PawnRuntime(values)
        common(runtime)
        runtime.bind('nav_cancel_route', lambda route: None)
        runtime.bind('nav_changed', lambda: None)

        def bucket(x, y):
            return hash_function(x, y) if hash_function else (x+8*y) % 64

        def members(node):
            if values['gNodeFlags'][node] & 6:
                return []
            x, y, z = values['gNodeOrigin'][node]
            return [i for i, area in enumerate(areas)
                    if area[0]-0.01 <= x <= area[2]+0.01 and area[1]-0.01 <= y <= area[3]+0.01
                    and not (values['gAreaFlags'][i] & 1 and not values['gNodeFlags'][node] & 1)
                    and abs(z-(area[4]-((x-area[0])*area[5][0]+(y-area[1])*area[5][1])/area[5][2])) <= 1.]

        def collect(node, out):
            found = members(node)
            out[:len(found)] = found
            return len(found)

        def find_near(point, radius, height):
            found = [i for i in range(values['gNodeCount']) if math.dist(values['gNodeOrigin'][i], point) < radius
                     and abs(values['gNodeOrigin'][i][2]-point[2]) <= height]
            return min(found, key=lambda i: math.dist(values['gNodeOrigin'][i], point), default=-1)

        def add_node(point, flag, radius):
            node = values['gNodeCount']
            if node == capacity:
                return -1
            values['gNodeCount'] += 1
            values['gNodeOrigin'][node] = point[:]
            values['gNodeFlags'][node] = flag; values['gNodeRadius'][node] = radius
            index = bucket(math.floor(point[0]/256.), math.floor(point[1]/256.))
            values['gBucketNext'][node] = values['gBucketHead'][index]; values['gBucketHead'][index] = node
            return node

        def find_link(a, b):
            return next((i for i, e in enumerate(values['gNodeLinks'][a] or ()) if e[0] == b), -1)

        def add_link(a, b, flag, velocity):
            if a < 0 or b < 0 or a == b:
                return False
            row = [b, flag, *velocity, math.dist(values['gNodeOrigin'][a], values['gNodeOrigin'][b]), 0.]
            index = find_link(a, b)
            if index >= 0:
                values['gNodeLinks'][a][index] = row
            else:
                if not values['gNodeLinks'][a]:
                    values['gNodeLinks'][a] = []
                values['gNodeLinks'][a].append(row)
                values['gLinkCount'][a] += 1
            return True

        runtime.bind('nav_hash', bucket)
        runtime.bind('anpc_finite', math.isfinite)
        runtime.bind('nav_collect_node_areas', collect)
        runtime.bind('nav_common_area', lambda a, b: next(iter(set(members(a)) & set(members(b))), -1))
        runtime.bind('nav_attach_node', lambda node: None)
        runtime.bind('nav_find_near', find_near)
        runtime.bind('nav_add_node', add_node)
        runtime.bind('nav_find_link', find_link)
        runtime.bind('nav_add_link', add_link)
        runtime.load((includes()/'navigation_areas.inc').read_text(encoding='utf-8-sig'), (
            'nav_area_height', 'nav_area_contains', 'nav_area_at', 'nav_area_segment'))
        runtime.load((includes()/'navigation_portals.inc').read_text(encoding='utf-8-sig'), (
            'nav_region_begin', 'nav_region_border', 'nav_region_root', 'nav_region_union', 'nav_region_covered',
            'nav_region_match', 'nav_region_exit', 'nav_region_endpoint', 'nav_region_portal', 'nav_region_step'))
        for i, area in enumerate(areas):
            index = bucket(math.floor(area[0]/256.), math.floor(area[1]/256.))
            values['gAreaNext'][i] = values['gAreaHead'][index]
            values['gAreaHead'][index] = i
        for i, point in enumerate(points):
            index = bucket(math.floor(point[0]/256.), math.floor(point[1]/256.))
            values['gBucketNext'][i] = values['gBucketHead'][index]; values['gBucketHead'][index] = i
        for edge in edges:
            add_link(*edge)
        runtime.call('nav_region_begin')
        for node in protected:
            values['gRegionKeep'][node] = True

    def finish(self):
        for _ in range(5000):
            if self.runtime.call('nav_region_step'):
                return
        raise AssertionError('Source compaction failed to finish')

    def nodes(self):
        return [tuple(p) for p in self.values['gNodeOrigin'][:self.values['gNodeCount']]]


class BoundaryRegionTests(unittest.TestCase):
    def test_repeated_finalization_preserves_the_boundary_graph(self):
        fixture = RegionFixture([(40., 64., 0.), (300., 64., 0.)], [(0, 1, 0, [0., 0., 0.])])
        fixture.finish()
        expected = (fixture.nodes(), copy.deepcopy(fixture.values['gNodeLinks'][:fixture.values['gNodeCount']]))
        fixture.runtime.call('nav_region_begin')
        fixture.finish()
        self.assertEqual((fixture.nodes(), fixture.values['gNodeLinks'][:fixture.values['gNodeCount']]), expected)

    def test_corner_contact_does_not_create_a_shared_portal(self):
        fixture = RegionFixture([], areas=[(0., 0., 256., 128., 0., (0., 0., 1.)),
                                           (256., 128., 512., 256., 0., (0., 0., 1.))])
        fixture.finish()
        self.assertEqual(fixture.nodes(), [])

    def test_overlapping_height_spans_do_not_manufacture_interior_exits(self):
        fixture = RegionFixture([(80., 64., 0.), (80., 64., 96.)], [(0, 1, 0, [0., 0., 0.])],
                                areas=[(0., 0., 256., 128., 0., (0., 0., 1.)),
                                       (0., 0., 256., 128., 96., (0., 0., 1.))])
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(80., 64., 0.), (80., 64., 96.)])
        self.assertEqual(fixture.values['gRegionEdges'], 1)

    def test_small_radius_ordinary_interior_nodes_are_removed(self):
        fixture = RegionFixture([(40., 64., 0.), (180., 64., 0.)], [(0, 1, 0, [0., 0., 0.])])
        fixture.finish()
        self.assertEqual(fixture.nodes(), [])
        self.assertEqual(fixture.values['gRegionMap'][:2], [-1, -1])

    def test_exit_moves_to_boundary_without_reversing_physical_edge(self):
        fixture = RegionFixture([(40., 64., 0.), (180., 64., 0.), (300., 64., 0.)],
                                [(0, 1, 0, [0., 0., 0.]), (1, 2, 0, [0., 0., 0.])])
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(300., 64., 0.), (256., 64., 0.)])
        self.assertEqual(fixture.values['gLinkCount'][:2], [0, 1])
        self.assertEqual(fixture.values['gNodeLinks'][1][0][0], 0)

    def test_two_areas_share_a_boundary_anchor_and_no_interior_samples(self):
        areas = [(0., 0., 256., 128., 0., (0., 0., 1.)), (256., 0., 512., 128., 0., (0., 0., 1.))]
        fixture = RegionFixture([(40., 64., 0.), (320., 64., 0.)], [(0, 1, 0, [0., 0., 0.])], areas=areas)
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(256., 64., 0.)])
        self.assertEqual(fixture.values['gNodeFlags'][0], 8)
        self.assertEqual(fixture.values['gRegionEdges'], 0)

    def test_jump_endpoints_keep_real_takeoff_landing_and_velocity(self):
        fixture = RegionFixture([(40., 64., 0.), (180., 64., 0.)], [(0, 1, 1, [240., 0., 268.])])
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(40., 64., 0.), (180., 64., 0.)])
        self.assertEqual(fixture.values['gNodeLinks'][0][0][1:5], [1, 240., 0., 268.])
        self.assertEqual(fixture.values['gLinkCount'][1], 0)

    def test_frontier_protection_is_distinct_from_point_radius(self):
        fixture = RegionFixture([(40., 64., 0.), (180., 64., 0.)], protected=(0,))
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(40., 64., 0.)])
        self.assertEqual(fixture.values['gRegionMap'][:2], [0, -1])

    def test_absorbed_portal_is_removed_after_areas_merge(self):
        fixture = RegionFixture([(128., 64., 0.)], flags=(8,))
        fixture.finish()
        self.assertEqual(fixture.nodes(), [])

    def test_capacity_preflight_preserves_all_original_directed_edges(self):
        points = [(128., 64., 0.), (300., 64., 0.), (-40., 64., 0.), (128., 180., 0.)]
        fixture = RegionFixture(points, [(0, i, 0, [0., 0., 0.]) for i in (1, 2, 3)], capacity=5)
        fixture.finish()
        self.assertEqual(fixture.nodes(), points)
        self.assertEqual(fixture.values['gRegionMap'][:4], [0, 1, 2, 3])
        self.assertEqual(fixture.values['gRegionEdges'], 3)
        self.assertEqual(fixture.values['gRegionPortalLimit'], 1)

    def test_uniform_ramp_exit_uses_its_support_plane(self):
        normal = (-1./math.sqrt(5.), 0., 2./math.sqrt(5.))
        fixture = RegionFixture([(128., 64., 64.), (300., 64., 150.)], [(0, 1, 0, [0., 0., 0.])],
                                areas=[(0., 0., 256., 128., 0., normal)])
        fixture.finish()
        self.assertIn((256., 64., 128.), fixture.nodes())


class SharedPassageTests(unittest.TestCase):
    @staticmethod
    def row(count):
        return [(float(i*256), 0., float((i+1)*256), 128., 0., (0., 0., 1.)) for i in range(count)]

    def test_dense_bidirectional_crossings_collapse_to_one_shared_contact(self):
        points, edges = [], []
        for crossing in range(16):
            source = len(points)
            y = float(16+crossing*6)
            points.extend([(240., y, 0.), (272., y, 0.)])
            edges.extend([(source, source+1, 0, [0., 0., 0.]), (source+1, source, 0, [0., 0., 0.])])
        fixture = RegionFixture(points, edges, areas=self.row(2), capacity=64)
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(256., 64., 0.)])
        self.assertEqual(fixture.values['gRegionEdges'], 0)
        self.assertEqual(fixture.values['gRegionMap'][:32], [-1]*32)
        for area in range(2):
            self.assertTrue(fixture.runtime.call('nav_area_contains', area, fixture.nodes()[0]))

    def test_old_border_cluster_keeps_the_canonical_id_across_checkpoints(self):
        points = [(256., y, 0.) for y in (16., 40., 64., 90.)]
        fixture = RegionFixture(points, areas=self.row(2), flags=[8]*4)
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(256., 64., 0.)])
        self.assertEqual(fixture.values['gRegionMap'][:4], [-1, -1, 0, -1])
        self.assertEqual(fixture.values['gRegionPortals'], 0)
        fixture.runtime.call('nav_region_begin')
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(256., 64., 0.)])
        self.assertEqual(fixture.values['gRegionMap'][0], 0)
        self.assertEqual(fixture.values['gRegionPortals'], 0)

    def test_nearby_marker_inside_one_block_cannot_replace_shared_contact(self):
        fixture = RegionFixture([(255.5, 64., 0.)], areas=self.row(2), flags=[8])
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(256., 64., 0.)])
        self.assertEqual(fixture.values['gRegionMap'][0], -1)
        for area in range(2):
            self.assertTrue(fixture.runtime.call('nav_area_contains', area, fixture.nodes()[0]))

    def test_walk_across_three_blocks_uses_logical_passages(self):
        fixture = RegionFixture([(40., 32., 0.), (650., 96., 0.)], [(0, 1, 0, [0., 0., 0.])], areas=self.row(3))
        fixture.finish()
        self.assertCountEqual(fixture.nodes(), [(256., 64., 0.), (512., 64., 0.)])
        self.assertEqual(fixture.values['gRegionEdges'], 0)
        self.assertEqual(fixture.runtime.call('nav_region_root', 0, 0), fixture.runtime.call('nav_region_root', 0, 2))

    def test_connected_l_shape_preserves_walk_through_uncovered_space(self):
        areas = self.row(2)+[(256., 128., 512., 256., 0., (0., 0., 1.))]
        fixture = RegionFixture([(32., 32., 0.), (450., 220., 0.)], [(0, 1, 0, [0., 0., 0.])], areas=areas)
        self.assertFalse(fixture.runtime.call('nav_area_segment', fixture.nodes()[0], fixture.nodes()[1], 0))
        fixture.finish()
        self.assertEqual(fixture.values['gRegionEdges'], 1)
        self.assertIn((256., 64., 0.), fixture.nodes())
        self.assertIn((384., 128., 0.), fixture.nodes())
        self.assertEqual(fixture.values['gNodeCount'], 4)

    def test_physical_exit_is_projected_to_outer_border_of_adjacent_blocks(self):
        fixture = RegionFixture([(40., 32., 0.), (600., 32., 0.)], [(0, 1, 0, [0., 0., 0.])], areas=self.row(2))
        fixture.finish()
        self.assertCountEqual(fixture.nodes(), [(600., 32., 0.), (512., 32., 0.), (256., 64., 0.)])
        source = fixture.nodes().index((512., 32., 0.))
        destination = fixture.nodes().index((600., 32., 0.))
        self.assertEqual(fixture.values['gNodeLinks'][source][0][0], destination)
        self.assertEqual(fixture.values['gLinkCount'][destination], 0)

    def test_height_discontinuity_preserves_real_directed_drop(self):
        areas = [(0., 0., 256., 128., 128., (0., 0., 1.)), (256., 0., 512., 128., 0., (0., 0., 1.))]
        points = [(180., 64., 128.), (300., 64., 0.)]
        fixture = RegionFixture(points, [(0, 1, 2, [0., 0., 0.])], areas=areas)
        fixture.finish()
        self.assertEqual(fixture.nodes(), points)
        self.assertEqual(fixture.values['gNodeLinks'][0][0][:2], [1, 2])
        self.assertEqual(fixture.values['gLinkCount'][1], 0)
        self.assertEqual(fixture.values['gRegionPortals'], 0)

    def test_supported_ramp_drop_is_replaced_by_area_walking(self):
        normal = (-1./math.sqrt(5.), 0., 2./math.sqrt(5.))
        areas = [(0., 0., 256., 128., 0., normal), (256., 0., 512., 128., 128., normal)]
        fixture = RegionFixture([(300., 64., 150.), (40., 64., 20.)], [(0, 1, 2, [0., 0., 0.])], areas=areas)
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(256., 64., 128.)])
        self.assertEqual(fixture.values['gRegionEdges'], 0)

    def test_standing_connectivity_cannot_pass_through_crouch_only_block(self):
        for crouched in (False, True):
            fixture = RegionFixture([(40., 64., 0.), (650., 64., 0.)], [(0, 1, 0, [0., 0., 0.])],
                                    areas=self.row(3), flags=[int(crouched)]*2)
            fixture.values['gAreaFlags'][1] = 1
            fixture.finish()
            with self.subTest(crouched=crouched):
                self.assertEqual(fixture.values['gRegionEdges'], 0 if crouched else 1)
                self.assertEqual(fixture.runtime.call('nav_region_root', 1, 0), fixture.runtime.call('nav_region_root', 1, 2))
                self.assertNotEqual(fixture.runtime.call('nav_region_root', 0, 0), fixture.runtime.call('nav_region_root', 0, 2))
                canonical = [fixture.values['gNodeFlags'][i] for i, point in enumerate(fixture.nodes())
                             if point in ((256., 64., 0.), (512., 64., 0.)) and fixture.values['gNodeFlags'][i] & 1]
                self.assertEqual(canonical, [9, 9])

    def test_capacity_reserves_logical_passages_before_removing_walk_edges(self):
        points = [(40., 32., 0.), (650., 96., 0.)]
        fixture = RegionFixture(points, [(0, 1, 0, [0., 0., 0.])], areas=self.row(3), protected=(0,), capacity=2)
        fixture.finish()
        self.assertEqual(fixture.nodes(), points)
        self.assertEqual(fixture.values['gRegionMap'][:2], [0, 1])
        self.assertEqual(fixture.values['gNodeLinks'][0][0][:2], [1, 0])
        self.assertEqual(fixture.values['gRegionPortalLimit'], 1)

    def test_colliding_spatial_buckets_do_not_reserve_the_same_border_repeatedly(self):
        fixture = RegionFixture([], areas=self.row(2), capacity=1, hash_function=lambda x, y: 0)
        fixture.finish()
        self.assertEqual(fixture.nodes(), [(256., 64., 0.)])
        self.assertEqual(fixture.values['gRegionPortalLimit'], 0)
        self.assertEqual(fixture.values['gRegionPortals'], 1)


class CheckpointAndMovementTests(unittest.TestCase):
    def test_zero_node_checkpoint_remaps_block_owners_only_once(self):
        size = 4
        values = {
            'ANPC_MAX_NODES': size, 'ScanBlock': 19, 'BL_NODE': 11,
            'ANPC_SCAN_SAVE': 6, 'ANPC_SCAN_PAUSED': 3, 'ANPC_SCAN_SELECT': 2, 'ANPC_SCAN_SEED': 1,
            'SCAN_DONE': 1023, 'gSavePhase': -1, 'gSessionStage': 6, 'gSaveRecords': 1,
            'gActive': True, 'gCompleted': False, 'gSaveNode': 0,
            'gCompactCursor': 0, 'gCompactOriginal': 1, 'gCompactRemoved': 1,
            'gCompactBlocks': 0, 'gCompactBlockCount': 3, 'gCompactMap': [-1]*size,
            'gKnownCount': 1, 'gBotCount': 1, 'gUnreachable': [[9]*size],
            'gBlock': [[0]*19 for _ in range(3)], 'gGraphEpoch': 1, 'gBlockEpoch': 1,
            'gPrunedNodes': 1, 'gPortals': 0, 'gPortalLimit': 0,
        }
        for name in ('gCurrent', 'gSource', 'gGoalNode', 'gRouteGoal', 'gLaunchNode', 'gSeedAnchor', 'gPlanStart', 'gSenseNode'):
            values[name] = [0]
        values['gResumeStage'] = [3]
        for name in ('gMask', 'gVisits', 'gSeedRejected', 'gExploreParent', 'gParentClosed',
                     'gNodeBlock', 'gBlockMask', 'gBlockMaskEpoch', 'gInteriorMask', 'gPlanBlockedUntil'):
            values[name] = [0]*size
        runtime = PawnRuntime(values)
        common(runtime)
        runtime.bind('scan_work_available', lambda: True)
        runtime.bind('anpc_nav_count', lambda: 0)
        runtime.bind('anpc_nav_area_count', lambda: 1)
        runtime.bind('log_amx', lambda *args: None)
        runtime.load((includes()/'mapper_storage.inc').read_text(encoding='utf-8-sig'), ('scan_save_step',))
        for _ in range(6):
            if values['gSavePhase'] != -1:
                break
            runtime.call('scan_save_step')
        self.assertEqual(values['gSavePhase'], 0)
        self.assertEqual(values['gGraphEpoch'], 2)
        self.assertEqual(values['gBlockEpoch'], 2)
        self.assertEqual([row[11] for row in values['gBlock']], [-1, -1, -1])
        self.assertEqual(values['gCurrent'], [-1])
        self.assertEqual(values['gUnreachable'], [[0]*size])

    def test_world_collision_blocks_an_edge_but_a_crowd_does_not(self):
        movement = (includes()/'movement.inc').read_text(encoding='utf-8-sig')
        guard = next(c for c in conditions(body(movement, 'npc_progress')) if 'blocker > MaxClients' in c)
        for blocker, expected in ((-1, True), (0, True), (7, False), (99, False), (101, True)):
            self.assertEqual(predicate(guard, {'blocker': blocker, 'MaxClients': 32,
                             'anpc_is_npc': lambda entity: entity == 99}), expected)

    def test_sidestep_requires_floor_and_clear_actor_hull_before_walking(self):
        source = (includes()/'movement.inc').read_text(encoding='utf-8-sig')
        for floor_ok, fraction, ground, attack, expected in ((False, 1., True, False, False),
                (True, 0.5, True, False, False), (True, 1., True, False, True),
                (True, 1., False, False, False), (True, 1., True, True, False)):
            values = {'gActor': [[99, 1, False, int(attack)]], 'ACT_ENTITY': 0, 'ACT_SERIAL': 1, 'ACT_CROUCHED': 2,
                      'ACT_STATE': 3, 'ANPC_ATTACK': 1, 'FL_ONGROUND': 512, 'var_flags': 0,
                      'gStepSize': 18., 'gTrace': 1, 'degrees': 0, 'DONT_IGNORE_MONSTERS': 0,
                      'HULL_HEAD': 3, 'HULL_HUMAN': 1, 'EngFunc_TraceHull': 1,
                      'TR_flFraction': 1, 'TR_StartSolid': 2, 'TR_AllSolid': 3}
            runtime, walks = PawnRuntime(values), []
            common(runtime)
            runtime.bind('anpc_entity_feet', lambda entity, out: out.__setitem__(slice(None), [0., 0., 0.]))
            runtime.bind('floatcos', lambda angle, unit: math.cos(math.radians(angle)))
            runtime.bind('floatsin', lambda angle, unit: math.sin(math.radians(angle)))
            runtime.bind('anpc_ground_step', lambda a, b, duck, step, entity, trace, traces, out:
                         out.__setitem__(slice(None), b[:]) is None and floor_ok)
            runtime.bind('engfunc', lambda *args: None)

            def trace_value(trace, field, out=None):
                value = fraction if field == 1 else 0
                if out is not None:
                    out.put(value)
                return value

            runtime.bind('get_tr2', lambda *args: trace_value(*args[:2], args[2] if len(args) == 3 else None), (2,))
            runtime.bind('npc_live', lambda slot: True)
            runtime.bind('get_entvar', lambda entity, field: 512 if ground else 0)
            runtime.bind('npc_walk_straight', lambda *args: walks.append(args) is None)
            runtime.load(source, ('npc_safe_sidestep',))
            with self.subTest(floor=floor_ok, fraction=fraction):
                self.assertEqual(runtime.call('npc_safe_sidestep', 0, 60., 8.), expected)
                self.assertEqual(len(walks), int(expected))


class PursuitFixture:
    def __init__(self, points, feet, target, edges=None, flags=None, replacement=False):
        fields = ('TYPE', 'ENTITY', 'SERIAL', 'ROUTE', 'TARGET', 'CROUCHED', 'LADDER', 'STATE',
                  'PATH_VERSION', 'PATH_CURSOR', 'JUMP_CURSOR', 'NEXT_JUMP_PROBE', 'PROGRESS_VALID',
                  'DIRECT_UNTIL', 'DIRECT_OK', 'DIRECT_CROUCH', 'NEXT_REPATH', 'FROM_NODE', 'TO_NODE',
                  'LAST_SEEN', 'WAIT_DOOR', 'OBSTACLE_WAIT', 'YIELD_UNTIL',
                  'NEXT_ATTACK', 'KNOCKBACK_UNTIL', 'RECOVER_UNTIL', 'PATH_AREA')
        self.values = v = {'ACT_'+field: i for i, field in enumerate(fields)}
        end = len(fields)
        v['ACT_DIRECT_GOAL'], v['ACT_LAST_KNOWN'] = slice(end, end+3), slice(end+3, end+6)
        v['ACT_PATH_DESTINATION'] = slice(end+6, end+9)
        v.update(gActor=[[0]*(end+9)], gProfile=[[31, 1, 100.]], ANPC_CAPABILITIES=0, ANPC_GLOBAL_HUNT=1,
                 ANPC_SPEED=2, ANPC_CAP_CROUCH=1, ANPC_CAP_LADDER=4,
                 ANPC_NODE_CROUCH=1, ANPC_NODE_LADDER=2, ANPC_NODE_DISABLED=4, ANPC_NODE_PORTAL=8,
                 ANPC_LINK_JUMP=1, ANPC_LINK_DROP=2, ANPC_INVALID_NODE=-1, ANPC_ATTACK=2, ANPC_HUNT=1, ANPC_RECOVER=3,
                 ANPC_PATH_NONE=0, ANPC_PATH_PENDING=1, ANPC_PATH_READY=2,
                 ZERO_VECTOR=[0., 0., 0.], FL_ONGROUND=512, MOVETYPE_FLY=5,
                 var_flags=0, var_movetype=1, gPlayerVelocity=[[0., 0., 0.] for _ in range(33)],
                 gPlayerGroundFeet=[[0., 0., 0.] for _ in range(33)], gPlayerGroundValid=[False]*33,
                 EngFunc_TraceHull=1, IGNORE_MONSTERS=1, HULL_HEAD=3, HULL_HUMAN=1,
                 TR_flFraction=1, TR_StartSolid=2, TR_AllSolid=3, gTrace=1, gRepathInterval=0.75)
        for field, value in {'ENTITY': 99, 'SERIAL': 1, 'ROUTE': 65, 'TARGET': 7,
                             'PATH_VERSION': 6 if replacement else 7, 'NEXT_REPATH': 20.}.items():
            v['gActor'][0][v['ACT_'+field]] = value
        self.feet, self.target = list(feet), list(target)
        self.flags, self.points = flags or [0]*len(points), [list(point) for point in points]
        self.edges = edges or {(i, i+1): 0 for i in range(len(points)-1)}
        self.walkable, self.grounded, self.movetype, self.ladder = True, True, 0, lambda point: 0
        self.fraction = 1.
        self.moves, self.cancels, self.proofs, self.progress = [], [], [], []
        runtime = self.runtime = PawnRuntime(v)
        common(runtime)
        runtime.bind('anpc_entity_feet', lambda entity, out: out.__setitem__(slice(None), self.target if entity == 7 else self.feet))
        runtime.bind('get_entvar', lambda entity, field: (512 if self.grounded else 0) if field == 0 else self.movetype)
        runtime.bind('anpc_nav_path_size', lambda route: len(self.points))
        runtime.bind('anpc_nav_path_revision', lambda route: 7)
        runtime.bind('anpc_nav_path_node', lambda route, cursor: cursor)
        runtime.bind('anpc_nav_status', lambda route: 2)
        runtime.bind('anpc_nav_cancel', lambda route: self.cancels.append(route))
        runtime.bind('anpc_nav_area_at', lambda *args: -1)
        runtime.bind('anpc_nav_ladder', lambda point: self.ladder(point))

        def read_node(node, out, flag, radius):
            out[:] = self.points[node]; flag.put(self.flags[node]); radius.put(8.)
            return True

        def read_link(a, b, flag, velocity):
            flag.put(self.edges.get((a, b), 0)); velocity[:] = [0., 0., 0.]
            return (a, b) in self.edges

        def proof(a, b, duck, entity):
            self.proofs.append((tuple(a), tuple(b), bool(duck)))
            return self.walkable

        runtime.bind('anpc_nav_node', read_node, (2, 3))
        runtime.bind('anpc_nav_link', read_link, (2,))
        runtime.bind('anpc_nav_walkable', proof)
        runtime.bind('npc_move', lambda *args: self.moves.append((args[0], tuple(args[1]), *args[2:])))
        runtime.bind('npc_obstacle', lambda *args: 0)
        runtime.bind('npc_progress', lambda *args: self.progress.append(args))
        runtime.bind('npc_live', lambda slot: True)
        runtime.bind('npc_clear_route', lambda slot: self.cancels.append(slot))
        runtime.bind('npc_detach_ladder', lambda slot: None)
        runtime.bind('engfunc', lambda *args: None)
        runtime.bind('get_tr2', lambda trace, field, out=None:
                     out.put(self.fraction) if out is not None else 0, (2,))
        runtime.bind('anpc_distance_2d', lambda a, b: math.dist(a[:2], b[:2]))
        runtime.load((includes()/'perception.inc').read_text(encoding='utf-8-sig'), (
            'npc_goal_feet', 'npc_direct_segment', 'npc_chase_direct', 'npc_ladder_segment', 'npc_follow_route', 'npc_hunt'))


class PursuitTests(unittest.TestCase):
    def portal_route(self, flags=None, edges=None):
        fixture = PursuitFixture([(float(x), 0., 0.) for x in (0, 100, 200, 300)],
                                 (60., 0., 0.), (600., 0., 0.), flags=flags or [8]*4, edges=edges)
        fixture.values['gActor'][0][fixture.values['ACT_PATH_CURSOR']] = 1
        fixture.runtime.bind('anpc_nav_area_at', lambda *args: 0)
        fixture.runtime.bind('anpc_nav_area_segment', lambda *args: True)
        return fixture

    def test_small_portals_are_skipped_on_a_clear_covered_route(self):
        fixture = self.portal_route()
        fixture.runtime.call('npc_follow_route', 0, 0.05, 10.)
        self.assertEqual(fixture.moves[0][1], (300., 0., 0.))
        self.assertEqual(fixture.values['gActor'][0][fixture.values['ACT_PATH_CURSOR']], 3)
        self.assertIn(((60., 0., 0.), (300., 0., 0.), False), fixture.proofs)

    def test_small_portal_shortcut_stops_at_real_jump_takeoff(self):
        fixture = self.portal_route(edges={(0, 1): 0, (1, 2): 0, (2, 3): 1})
        fixture.runtime.call('npc_follow_route', 0, 0.05, 10.)
        self.assertEqual(fixture.moves[0][1], (200., 0., 0.))
        self.assertEqual(fixture.values['gActor'][0][fixture.values['ACT_PATH_CURSOR']], 2)

    def test_portal_shortcut_requires_clear_hull_coverage_and_same_posture(self):
        for restriction in ('hull', 'coverage', 'posture'):
            fixture = self.portal_route(flags=[8, 8, 9, 9] if restriction == 'posture' else None)
            if restriction == 'hull':
                fixture.walkable = False
            if restriction == 'coverage':
                fixture.runtime.bind('anpc_nav_area_segment', lambda a, b, caps: b[0] <= 100.)
            fixture.runtime.call('npc_follow_route', 0, 0.05, 10.)
            with self.subTest(restriction=restriction):
                self.assertEqual(fixture.moves[0][1], (100., 0., 0.))
                self.assertEqual(fixture.values['gActor'][0][fixture.values['ACT_PATH_CURSOR']], 1)

    def test_ready_replacement_is_consumed_before_moving_target_requests_again(self):
        fixture = PursuitFixture([(0., 0., 0.), (100., 0., 0.)],
                                 (0., 0., 0.), (600., 0., 0.), replacement=True)
        fixture.values['gActor'][0][fixture.values['ACT_NEXT_REPATH']] = 0.
        fixture.runtime.bind('npc_can_hit', lambda *args: False)
        fixture.runtime.bind('npc_state', lambda *args: None)
        fixture.runtime.bind('anpc_nav_area_segment', lambda *args: False)
        fixture.runtime.bind('anpc_nav_request_to', lambda *args: self.fail('Ready path was replaced before following'))
        fixture.runtime.call('npc_hunt', 0, 0.05, 10.)
        self.assertEqual(fixture.moves[0][1], (100., 0., 0.))
        self.assertEqual(fixture.values['gActor'][0][fixture.values['ACT_PATH_VERSION']], 7)

    def test_final_connector_farther_than_interception_range_is_walked(self):
        fixture = PursuitFixture([(0., 0., 0.)], (0., 0., 0.), (300., 0., 0.))
        fixture.runtime.call('npc_follow_route', 0, 0.05, 10.)
        self.assertEqual(fixture.moves[0][1], (300., 0., 0.))
        self.assertEqual(fixture.values['gActor'][0][fixture.values['ACT_PATH_CURSOR']], 1)
        self.assertEqual(fixture.cancels, [])
        self.assertIn(((0., 0., 0.), (300., 0., 0.), False), fixture.proofs)

    def test_finished_route_waits_for_door_then_walks_connector_after_opening(self):
        fixture = PursuitFixture([(0., 0., 0.)], (0., 0., 0.), (300., 0., 0.))
        v = fixture.values
        fixture.walkable = False
        v['gActor'][0][v['ACT_WAIT_DOOR']] = 88
        v['gActor'][0][v['ACT_OBSTACLE_WAIT']] = 12.
        fixture.runtime.bind('npc_obstacle', lambda *args: 88)
        fixture.runtime.call('npc_follow_route', 0, 0.05, 10.)
        self.assertEqual((fixture.moves, fixture.cancels, fixture.progress), ([], [], []))
        fixture.walkable = True
        fixture.runtime.call('npc_follow_route', 0, 0.05, 10.2)
        self.assertEqual(fixture.moves[0][1], (300., 0., 0.))

    def test_replacement_joins_later_walk_node_from_current_feet(self):
        fixture = PursuitFixture([(0., 0., 0.), (100., 0., 0.), (200., 0., 0.)],
                                 (150., 0., 0.), (300., 0., 0.), replacement=True)
        fixture.runtime.call('npc_follow_route', 0, 0.05, 10.)
        self.assertEqual(fixture.moves[0][1], (200., 0., 0.))
        self.assertEqual(fixture.values['gActor'][0][fixture.values['ACT_PATH_CURSOR']], 2)

    def test_replacement_never_skips_jump_takeoff(self):
        fixture = PursuitFixture([(0., 0., 0.), (100., 0., 0.), (200., 0., 0.)],
                                 (150., 0., 0.), (300., 0., 0.), edges={(0, 1): 0, (1, 2): 1}, replacement=True)
        fixture.runtime.call('npc_follow_route', 0, 0.05, 10.)
        self.assertEqual(fixture.moves[0][1], (100., 0., 0.))
        self.assertEqual(fixture.values['gActor'][0][fixture.values['ACT_PATH_CURSOR']], 1)

    def test_player_jump_keeps_supported_goal_until_landing(self):
        fixture = PursuitFixture([], (0., 0., 0.), (100., 0., 0.))
        goal = [0., 0., 0.]
        fixture.runtime.call('npc_goal_feet', 7, goal)
        fixture.grounded = False; fixture.target[:] = [120., 0., 50.]
        fixture.runtime.call('npc_goal_feet', 7, goal)
        self.assertEqual(goal, [100., 0., 0.])
        fixture.grounded = True; fixture.target[:] = [150., 0., 20.]
        fixture.runtime.call('npc_goal_feet', 7, goal)
        self.assertEqual(goal, [150., 0., 20.])

    def test_ladder_player_preserves_real_height_and_requires_same_clear_volume(self):
        fixture = PursuitFixture([(0., 0., 100.)], (0., 0., 100.), (0., 0., 150.), flags=[2])
        fixture.values['gPlayerGroundValid'][7] = True
        fixture.grounded = False; fixture.movetype = 5; fixture.walkable = False
        fixture.ladder = lambda point: 88
        goal = [0., 0., 0.]
        fixture.runtime.call('npc_goal_feet', 7, goal)
        self.assertEqual(goal, [0., 0., 150.])
        fixture.runtime.call('npc_follow_route', 0, 0.05, 10.)
        self.assertEqual(fixture.moves[0][1:4], ((0., 0., 150.), 2, 0))
        fixture.fraction = 0.5
        self.assertFalse(fixture.runtime.call('npc_ladder_segment', 0, fixture.feet, fixture.target))
        fixture.fraction = 1.; fixture.ladder = lambda point: 88 if point[2] < 125. else 89
        self.assertFalse(fixture.runtime.call('npc_ladder_segment', 0, fixture.feet, fixture.target))

    def test_yield_is_respected_before_crouch_and_fallback_sidestep(self):
        fixture = PursuitFixture([], (0., 0., 0.), (100., 0., 0.))
        v, runtime = fixture.values, fixture.runtime
        v.update(gStepSize=18., ANPC_ANIM_IDLE=0, var_velocity=2)
        runtime.bind('npc_posture', lambda *args: True)
        runtime.bind('npc_face', lambda *args: 0.)
        runtime.bind('anpc_nav_area_segment', lambda *args: False)
        runtime.bind('set_entvar', lambda *args: None)
        runtime.bind('npc_animation', lambda *args: None)

        def yield_to_peer(slot, feet, yaw, step, now, blocker):
            v['gActor'][slot][v['ACT_YIELD_UNTIL']] = now+0.15
            blocker.put(100)
            return False

        runtime.bind('npc_avoid_actor', yield_to_peer, (5,))
        runtime.bind('npc_walk_straight', lambda *args: self.fail('Yield attempted forward movement'))
        runtime.bind('npc_obstacle', lambda *args: self.fail('Yield ran obstacle fallback'))
        runtime.load((includes()/'movement.inc').read_text(encoding='utf-8-sig'), ('npc_move',))
        runtime.call('npc_move', 0, fixture.target, 0, 0, [0., 0., 0.], 0.05, 10.)
        self.assertEqual(len(fixture.progress), 1)
        self.assertEqual(fixture.progress[0][-1], 100)


if __name__ == '__main__':
    unittest.main()
