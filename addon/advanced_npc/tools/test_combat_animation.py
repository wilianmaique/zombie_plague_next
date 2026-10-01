"""Execute installed Pawn combat/animation/viewer functions with native doubles.

Slab collisions and binary studio descriptors supply independent fixtures.
This is source regression coverage, not an AMXX VM, a compiler or an HLDS run.
"""
import io
import math
import re
import struct
import unittest
from pathlib import Path

from pawn_test_runtime import PawnRuntime, Ref
from test_boundary_routes import common, includes
from test_adaptive_navigation import text


ROOT = Path(__file__).resolve().parents[1]


def source(name):
    return (includes()/name).read_text(encoding='utf-8-sig')


def layout(values, text, name):
    section = re.search(r'enum\s+(?:_:)?'+name+r'\s*\{([^}]+)\}', text)[1]
    section = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/', '', section)
    size = 0
    for field in section.split(','):
        match = re.fullmatch(r'\s*(?:\w+:)?(\w+)(?:\[(\d+)\])?\s*', field)
        assert match, field
        width = int(match[2] or 1)
        values[match[1]] = slice(size, size+width) if width > 1 else size
        size += width
    values[name] = size
    return size


def segment_box(start, end, lo, hi):
    """Independent segment/slab intersection, with the entry plane normal."""
    inside = all(lo[i]+1e-6 < start[i] < hi[i]-1e-6 for i in range(3))
    entry, leave, normal = 0., 1., [0., 0., 0.]
    for axis in range(3):
        delta = end[axis]-start[axis]
        if abs(delta) < 1e-8:
            if start[axis] < lo[axis] or start[axis] > hi[axis]:
                return None
            continue
        a, b = (lo[axis]-start[axis])/delta, (hi[axis]-start[axis])/delta
        n = -1. if a < b else 1.
        a, b = min(a, b), max(a, b)
        if a > entry:
            entry, normal = a, [0., 0., 0.]
            normal[axis] = n
        leave = min(leave, b)
        if entry > leave:
            return None
    return (max(0., entry), normal, inside) if leave >= 0. and entry <= 1. else None


class ActorFixture:
    def __init__(self):
        v = self.values = {}
        core = (ROOT/'anpc_core.sma').read_text(encoding='utf-8-sig')
        actor_size = layout(v, core, 'Actor')
        animation_size = layout(v, core, 'AnimationData')
        profile_size = layout(v, source('advanced_npc_limits.inc'), 'AnpcProfile')
        v.update(gActor=[[0]*actor_size for _ in range(2)], gProfile=[[0]*profile_size],
                 gAnimation=[[[i, 128., 0., i in (0, 1, 2, 4), True] for i in range(7)]],
                 MaxClients=32, ANPC_MAX_ACTORS=2, ANPC_CAP_CROUCH=1, ANPC_CAP_JUMP=2,
                 ANPC_CAP_LADDER=4, ANPC_CAP_BREAKABLE=16, ANPC_CAP_DOOR=8,
                 ANPC_ANIM_IDLE=0, ANPC_ANIM_RUN=1, ANPC_ANIM_CROUCH=2,
                 ANPC_ANIM_JUMP=3, ANPC_ANIM_ATTACK=4, ANPC_ANIM_CROUCH_ATTACK=5,
                 ANPC_ANIM_DEATH=6, ANPC_IDLE=0, ANPC_HUNT=1, ANPC_ATTACK=2,
                 ANPC_RECOVER=3, ANPC_DEAD=4, ANPC_PATH_NONE=0, ANPC_PATH_PENDING=1,
                 ANPC_PATH_READY=2, ANPC_PATH_FAILED=3, ANPC_INVALID_NODE=-1,
                 ANPC_NODE_CROUCH=1, ANPC_NODE_LADDER=2, ANPC_LINK_JUMP=1,
                 ANPC_LINK_DROP=2, FL_ONGROUND=512, FL_DUCKING=16384,
                 FL_PARTIALGROUND=1024, MOVETYPE_FLY=5, MOVETYPE_STEP=4,
                 DAMAGE_NO=0., ANPC_BLOCK=1, HULL_HUMAN=1, HULL_HEAD=3,
                 IGNORE_MONSTERS=1, DONT_IGNORE_MONSTERS=0, degrees=0,
                 floatround_floor=0, floatround_ceil=1,
                 DMG_SLASH=4, Ham_TakeDamage=1, gTrace=1, gStepSize=18.,
                 ZERO_VECTOR=[0., 0., 0.], STAND_MINS=[-16., -16., -36.],
                 STAND_MAXS=[16., 16., 36.], DUCK_MINS=[-16., -16., -18.],
                 DUCK_MAXS=[16., 16., 18.], gRepathInterval=.75,
                 gPlayerVelocity=[[0., 0., 0.] for _ in range(33)])
        v.update(gLocalJumpTime=0., gLocalJumpTrials=0)
        assert animation_size == 5
        for name in ('origin', 'mins', 'maxs', 'absmin', 'absmax', 'flags',
                     'velocity', 'movetype', 'frame', 'sequence', 'animtime',
                     'framerate', 'health', 'takedamage', 'groundentity', 'angles'):
            v['var_'+name] = name
        for name in ('TraceLine', 'TraceHull', 'SetSize', 'SetOrigin'):
            v['EngFunc_'+name] = name
        for name in ('StartSolid', 'AllSolid', 'pHit', 'flFraction', 'vecEndPos', 'vecPlaneNormal'):
            v['TR_'+name] = name
        v.update(FW_ATTACK_PRE=0, FW_ATTACK_POST=1, gForwards=[0, 1])
        for name, value in dict(ANPC_SPEED=300., ANPC_ATTACK_RANGE=72.,
                                ANPC_ATTACK_WINDUP=.28, ANPC_ATTACK_COOLDOWN=1.,
                                ANPC_DAMAGE=35., ANPC_GLOBAL_HUNT=1,
                                ANPC_CAPABILITIES=31, ANPC_GRAVITY=.8,
                                ANPC_JUMP_SPEED=320.).items():
            v['gProfile'][0][v[name]] = value
        self.now = 10.
        self.world = [(0, [-10000., -10000., -1000.], [10000., 10000., 0.])]
        self.entities = {99: self.entity([0., 0., 36.1]), 7: self.entity([100., 0., 36.])}
        self.userids = {7: 17}
        self.allow_target, self.removed, self.block_damage = True, False, False
        self.damage, self.faces, self.states, self.probes, self.requests = [], [], [], [], []
        self.trace_count, self.pre_hook, self.post_hook = 0, None, None
        self.support, self.hull_clear = True, True
        self.path_status, self.path_count, self.rejected = 0, 0, []
        self.move_requests = []
        a = v['gActor'][0]
        for name, value in dict(ACT_ENTITY=99, ACT_SERIAL=1, ACT_TARGET=7,
                                ACT_TARGET_USERID=17, ACT_ROUTE=65,
                                ACT_FROM_NODE=-1, ACT_TO_NODE=-1,
                                ACT_JUMP_CURSOR=-1, ACT_STATE=1).items():
            a[v[name]] = value
        a[v['ACT_LAST_KNOWN']] = [100., 0., 0.]
        r = self.runtime = PawnRuntime(v)
        common(r)
        r.bind('clamp', lambda n, lo, hi: max(lo, min(hi, n)))
        r.bind('get_gametime', lambda: self.now)
        r.bind('get_cvar_float', lambda name: 800.)
        r.bind('floatatan2', lambda y, x, mode: math.degrees(math.atan2(y, x)))
        r.bind('floatcos', lambda angle, mode: math.cos(math.radians(angle)))
        r.bind('floatsin', lambda angle, mode: math.sin(math.radians(angle)))
        r.bind('anpc_distance_2d', lambda a, b: math.dist(a[:2], b[:2]))
        r.bind('get_entvar', self.get_var)
        r.bind('set_entvar', self.set_var)
        r.bind('get_tr2', self.get_trace, (2,))
        r.bind('engfunc', self.engine)
        r.bind('anpc_entity_feet', self.get_feet)
        r.bind('is_entity', lambda entity: entity in self.entities)
        r.bind('is_user_alive', lambda entity: entity in self.entities and self.entities[entity]['health'] > 0.)
        r.bind('get_user_userid', lambda entity: self.userids.get(entity, 0))
        r.bind('FClassnameIs', lambda entity, name: entity > 32 and entity != 99 and name == 'func_breakable')
        r.bind('npc_live', lambda slot: not self.removed and v['gActor'][slot][v['ACT_ENTITY']] == 99 and v['gActor'][slot][v['ACT_STATE']] != 4)
        r.bind('npc_target_allowed', lambda slot, target: self.allow_target and not self.removed and self.entities[target]['health'] > 0.)
        r.bind('npc_state', self.state)
        r.bind('npc_face', lambda slot, goal, dt: self.faces.append(tuple(goal)) or 0.)
        r.bind('npc_detach_ladder', lambda slot: a.__setitem__(v['ACT_LADDER'], 0))
        r.bind('ExecuteForward', self.forward, (1,))
        r.bind('ExecuteHamB', lambda *args: self.damage.append(args))
        r.bind('anpc_ground_floor', self.ground_floor)
        r.bind('anpc_ground_hull', lambda *args: self.hull_clear)
        r.bind('anpc_nav_cancel', lambda route: None)
        r.bind('anpc_nav_status', lambda route: self.path_status)
        r.bind('anpc_nav_path_size', lambda route: self.path_count)
        r.bind('anpc_nav_path_revision', lambda route: 0)
        r.bind('anpc_nav_area_at', lambda *args: -1)
        r.bind('anpc_nav_area_segment', lambda *args: False)
        r.bind('anpc_nav_request_to', self.request)
        r.bind('npc_follow_route', lambda *args: None)
        r.bind('npc_chase_direct', lambda slot, feet, goal, *args: self.move_requests.append(tuple(goal)) and False)
        r.bind('npc_reject_target', lambda slot, now: self.rejected.append(now))
        r.bind('npc_goal_feet', self.get_feet)
        r.load(source('studio.inc'), ('npc_animation', 'npc_animate'))
        r.load(source('combat.inc'), ('npc_melee_contact', 'npc_can_hit', 'npc_begin_attack', 'npc_attack_impact'))
        r.load(source('movement.inc'), ('npc_stop_ground', 'npc_posture', 'npc_jump_solution', 'npc_jump', 'npc_try_local_jump'))
        r.load(source('perception.inc'), ('npc_clear_route', 'npc_melee_goal', 'npc_retry_melee_goal', 'npc_hunt'))
        r.call('npc_animation', 0, 0, True)

    @staticmethod
    def entity(origin):
        return dict(origin=origin[:], mins=[-16., -16., -36.], maxs=[16., 16., 36.],
                    flags=512, velocity=[0., 0., 0.], movetype=4, frame=0.,
                    animtime=0., sequence=0, framerate=0., health=100.,
                    takedamage=1., angles=[0., 0., 0.])

    @property
    def actor(self):
        return self.values['gActor'][0]

    def get(self, name):
        return self.actor[self.values['ACT_'+name]]

    def put(self, name, value):
        self.actor[self.values['ACT_'+name]] = value

    def get_var(self, entity, field, out=None):
        data = self.entities[entity]
        if field in ('absmin', 'absmax'):
            value = [x+y for x, y in zip(data['origin'], data['mins' if field == 'absmin' else 'maxs'])]
        else:
            value = data.get(field, 0)
        if out is None:
            return value
        out[:] = value[:]

    def set_var(self, entity, field, value):
        self.entities[entity][field] = list(value[:]) if hasattr(value, '__getitem__') else value

    def get_trace(self, trace, field, out=None):
        value = self.trace[field]
        if out is None:
            return value
        if hasattr(out, 'put'):
            out.put(value)
        else:
            out[:] = value[:]

    def get_feet(self, entity, out):
        out[:] = self.entities[entity]['origin'][:]
        out[2] += self.entities[entity]['mins'][2]

    def state(self, slot, state):
        self.values['gActor'][slot][self.values['ACT_STATE']] = state
        self.states.append(state)

    def forward(self, kind, result, *args):
        result.put(int(self.block_damage))
        hook = self.pre_hook if kind == 0 else self.post_hook
        if hook:
            hook()

    def ground_floor(self, point, duck, above, below, entity, trace, traces, out):
        self.probes.append(tuple(point))
        if not self.support:
            return False
        height = 0.
        for entity, lo, hi in self.world[1:]:
            if lo[0]-16. <= point[0] <= hi[0]+16. and lo[1]-16. <= point[1] <= hi[1]+16.:
                height = max(height, hi[2])
        if height > point[2]+above+.2 or height < point[2]-below:
            return False
        out[:] = [point[0], point[1], height]
        return True

    def request(self, route, feet, goal, *args):
        self.requests.append((tuple(feet), tuple(goal)))
        self.path_status = 1
        return True

    def engine(self, operation, *args):
        if operation == 'SetSize':
            entity, lo, hi = args
            self.entities[entity]['mins'], self.entities[entity]['maxs'] = lo[:], hi[:]
            return
        if operation == 'SetOrigin':
            self.entities[args[0]]['origin'] = list(args[1][:])
            return
        start, end, ignore = args[:3]
        ignored = args[-2]
        hull = args[3] if operation == 'TraceHull' else None
        radius, height = (16., 18. if hull == 3 else 36.) if hull else (0., 0.)
        boxes = list(self.world)
        if not ignore:
            for entity in self.entities:
                if entity == ignored:
                    continue
                boxes.append((entity, self.get_var(entity, 'absmin'), self.get_var(entity, 'absmax')))
        hit, fraction, normal, solid = 0, 1., [0., 0., 0.], False
        for entity, lo, hi in boxes:
            lo = [lo[0]-radius, lo[1]-radius, lo[2]-height]
            hi = [hi[0]+radius, hi[1]+radius, hi[2]+height]
            intersection = segment_box(start, end, lo, hi)
            if intersection and intersection[0] < fraction:
                fraction, normal, solid = intersection
                hit = entity
        self.trace = dict(pHit=hit, flFraction=fraction, StartSolid=solid,
                          AllSolid=solid and start[:] == end[:], vecPlaneNormal=normal,
                          vecEndPos=[start[i]+(end[i]-start[i])*fraction for i in range(3)])
        self.trace_count += 1

    def advance(self, now):
        self.now = now
        self.runtime.call('npc_animate', 0, now)


class CombatTests(unittest.TestCase):
    def attacking(self):
        f = ActorFixture()
        f.entities[7]['origin'][0] = 70.
        f.runtime.call('npc_begin_attack', 0, 7, f.now)
        return f

    def test_single_impact_and_full_attack_commitment(self):
        f = self.attacking()
        for now in (10.1, 10.28, 10.3, 10.8, 10.99):
            f.runtime.call('npc_attack_impact', 0, .05, now)
            self.assertEqual(f.get('STATE'), 2)
        self.assertEqual(len(f.damage), 1)
        f.runtime.call('npc_attack_impact', 0, .05, 11.)
        self.assertEqual(f.get('STATE'), 1)
        self.assertEqual(f.get('ATTACK_VICTIM'), 0)
        self.assertTrue(f.faces)

    def test_reentrant_pre_forward_cannot_repeat_the_strike(self):
        f = self.attacking()
        f.pre_hook = lambda: f.runtime.call('npc_attack_impact', 0, .05, 10.4)
        f.runtime.call('npc_attack_impact', 0, .05, 10.4)
        self.assertEqual(len(f.damage), 1)

    def test_miss_does_not_become_a_late_hit_after_windup(self):
        f = self.attacking()
        f.entities[7]['origin'][0] = 200.
        f.runtime.call('npc_attack_impact', 0, .05, 10.4)
        f.entities[7]['origin'][0] = 70.
        f.runtime.call('npc_attack_impact', 0, .05, 10.8)
        self.assertEqual(f.damage, [])

    def test_userid_change_filter_or_block_at_impact_prevents_damage(self):
        for change in ('userid', 'filter', 'block', 'remove', 'range', 'userid_in_forward'):
            f = self.attacking()
            if change == 'userid':
                f.userids[7] = 18
            elif change == 'filter':
                f.allow_target = False
            elif change == 'block':
                f.block_damage = True
            elif change == 'remove':
                f.pre_hook = lambda: setattr(f, 'removed', True)
            elif change == 'range':
                f.pre_hook = lambda: f.entities[7]['origin'].__setitem__(0, 200.)
            else:
                f.pre_hook = lambda: f.userids.__setitem__(7, 18)
            f.runtime.call('npc_attack_impact', 0, .05, 10.4)
            with self.subTest(change=change):
                self.assertEqual(f.damage, [])

    def test_cooldown_holds_reachable_victim_without_requesting_movement(self):
        f = ActorFixture()
        f.entities[7]['origin'][0] = 70.
        f.put('NEXT_ATTACK', 11.)
        f.runtime.call('npc_hunt', 0, .05, 10.5)
        self.assertEqual((f.move_requests, f.requests, f.damage), ([], [], []))
        self.assertEqual(f.get('ANIMATION'), 0)
        self.assertEqual(f.entities[99]['velocity'], [0., 0., 0.])

    def test_upper_visible_contact_can_hit_over_short_cover(self):
        f = ActorFixture()
        f.entities[7]['origin'][0] = 60.
        f.world.append((0, [25., -20., 0.], [35., 20., 65.]))
        self.assertTrue(f.runtime.call('npc_can_hit', 0, 7))
        self.assertEqual(f.trace_count, 3)

    def test_solid_wall_peers_and_out_of_range_victim_block_all_contacts(self):
        for obstacle in ('wall', 'peer', 'range', 'solid_start'):
            f = ActorFixture()
            f.entities[7]['origin'][0] = 60.
            if obstacle == 'wall':
                f.world.append((0, [25., -20., 0.], [35., 20., 200.]))
            elif obstacle == 'peer':
                f.entities[98] = f.entity([30., 0., 36.])
            elif obstacle == 'range':
                f.entities[7]['origin'][0] = 200.
            else:
                f.world.append((0, [-10., -10., 50.], [10., 10., 100.]))
            with self.subTest(obstacle=obstacle):
                self.assertFalse(f.runtime.call('npc_can_hit', 0, 7))
                self.assertLessEqual(f.trace_count, 3)

    def test_breakable_uses_its_nearest_surface_and_engine_damage(self):
        f = ActorFixture()
        f.entities[90] = f.entity([180., 0., 36.])
        f.entities[90]['mins'][0], f.entities[90]['maxs'][0] = -125., 125.
        f.runtime.call('npc_begin_attack', 0, 90, 10.)
        f.runtime.call('npc_attack_impact', 0, .05, 10.4)
        self.assertEqual(f.damage[0][1], 90)


class AnimationTests(unittest.TestCase):
    def test_stopped_runner_switches_to_idle_at_normal_rate(self):
        f = ActorFixture()
        f.runtime.call('npc_animation', 0, 1, True)
        f.advance(10.05)
        self.assertEqual(f.get('ANIMATION'), 0)
        self.assertEqual(f.entities[99]['frame'], 0.)
        f.advance(10.25)
        self.assertAlmostEqual(f.entities[99]['frame'], 25.6)
        self.assertEqual(f.entities[99]['framerate'], 1.)

    def test_new_sequence_does_not_advance_by_old_think_delta(self):
        f = ActorFixture()
        f.entities[7]['origin'][0] = 70.
        f.now = 10.2
        f.runtime.call('npc_begin_attack', 0, 7, f.now)
        f.advance(10.2)
        self.assertEqual(f.entities[99]['frame'], 0.)
        f.advance(10.3)
        self.assertAlmostEqual(f.entities[99]['frame'], 25.6)

    def test_running_rate_uses_actual_motion_not_requested_speed(self):
        f = ActorFixture()
        f.entities[99]['origin'][0] = 7.5  # 150 units/s, half the profile speed.
        f.advance(10.05)
        self.assertEqual(f.get('ANIMATION'), 1)
        self.assertAlmostEqual(f.entities[99]['framerate'], .5)
        f.entities[99]['origin'][0] += 7.5
        f.advance(10.1)
        self.assertAlmostEqual(f.entities[99]['frame'], 3.2)
        self.assertAlmostEqual(f.get('MOVE_VELOCITY')[0], 150.)

    def test_mdl_ground_speed_takes_precedence_over_profile_speed(self):
        f = ActorFixture()
        f.values['gAnimation'][0][1][f.values['ANIM_GROUND_SPEED']] = 150.
        f.entities[99]['origin'][0] += 7.5
        f.advance(10.05)
        self.assertAlmostEqual(f.entities[99]['framerate'], 1.)

    def test_stationary_crouch_keeps_hull_pose_and_freezes_gait(self):
        f = ActorFixture()
        self.assertTrue(f.runtime.call('npc_posture', 0, True))
        feet = [0., 0., 0.]
        f.get_feet(99, feet)
        f.advance(10.05)
        self.assertEqual(f.get('ANIMATION'), 2)
        self.assertEqual(f.entities[99]['frame'], 0.)
        self.assertEqual(f.entities[99]['framerate'], 0.)
        self.assertAlmostEqual(feet[2], .2)
        f.advance(10.25)
        self.assertEqual(f.entities[99]['frame'], 0.)

    def test_real_tunnel_keeps_crouch_attack_pose(self):
        f = ActorFixture()
        f.entities[7]['origin'][0] = 70.
        f.runtime.call('npc_posture', 0, True)
        f.world.append((0, [-50., -50., 50.], [50., 50., 100.]))
        f.runtime.call('npc_begin_attack', 0, 7, 10.)
        self.assertTrue(f.get('CROUCHED'))
        self.assertEqual(f.get('ANIMATION'), 5)

    def test_looping_one_shot_cannot_wrap_in_client_extrapolation(self):
        f = ActorFixture()
        f.put('STATE', 2)
        f.runtime.call('npc_animation', 0, 4, True)
        f.put('ANIM_SCALE', 2.)
        for tick in range(1, 30):
            f.advance(10.+tick*.05)
        self.assertEqual(f.entities[99]['frame'], 255.)
        self.assertEqual(f.entities[99]['framerate'], 0.)

    def test_locomotion_loop_wraps_and_death_stays_on_last_pose(self):
        f = ActorFixture()
        f.entities[99]['frame'] = 250.
        f.advance(10.2)
        self.assertAlmostEqual(f.entities[99]['frame'], 19.6)
        f.put('STATE', 4)
        f.runtime.call('npc_animation', 0, 6, True)
        for tick in range(1, 50):
            f.advance(10.2+tick*.05)
        self.assertEqual(f.entities[99]['frame'], 255.)
        self.assertEqual(f.entities[99]['framerate'], 0.)


class CrowdTests(unittest.TestCase):
    def test_walkmove_peer_prediction_uses_observed_displacement(self):
        f = ActorFixture()
        v, r = f.values, f.runtime
        f.entities[98] = f.entity([50., 50., 36.1])
        v['gActor'][1][v['ACT_ENTITY']] = 98
        v['gActor'][1][v['ACT_SERIAL']] = 2
        v['gActor'][1][v['ACT_MOVE_VELOCITY']] = [0., -120., 0.]
        r.bind('npc_live', lambda slot: v['gActor'][slot][v['ACT_ENTITY']] in f.entities)
        sidesteps, blocker = [], [0]
        r.bind('npc_safe_sidestep', lambda slot, yaw, distance: sidesteps.append(yaw) or True)
        r.load(source('ground.inc'), ('anpc_ground_stride',))
        r.load(source('movement.inc'), ('npc_avoid_actor',))
        ref = Ref(lambda: blocker[0], lambda value: blocker.__setitem__(0, value))
        self.assertTrue(r.call('npc_avoid_actor', 0, [0., 0., .1], 0., 15., 10., ref))
        self.assertEqual(blocker[0], 98)
        self.assertEqual(sidesteps, [-60.])
        # Airborne actors use engine velocity instead of the ground gait cache.
        f.entities[98]['flags'] = 0
        sidesteps.clear()
        self.assertFalse(r.call('npc_avoid_actor', 0, [0., 0., .1], 0., 15., 10.1, ref))
        self.assertEqual(sidesteps, [])

    def test_crowd_collision_does_not_crouch_but_a_real_low_passage_can(self):
        for tunnel in (False, True):
            f = ActorFixture()
            r = f.runtime
            if tunnel:
                f.world.append((0, [-50., -50., 50.], [50., 50., 100.]))
            r.bind('npc_walk_posture', lambda *args: False)
            r.bind('npc_avoid_actor', lambda *args: False)
            r.bind('npc_walk_straight', lambda *args: bool(f.get('CROUCHED')))
            r.bind('npc_obstacle', lambda *args: 0)
            r.bind('npc_steer_local', lambda *args: True)
            r.bind('npc_progress', lambda *args: None)
            r.bind('anpc_nav_walkable', lambda a, b, duck, entity: bool(duck) or not tunnel)
            r.load(source('movement.inc'), ('npc_move',))
            r.call('npc_move', 0, [100., 0., .1], 0, 0, [0., 0., 0.], .05, 10.)
            with self.subTest(tunnel=tunnel):
                self.assertEqual(bool(f.get('CROUCHED')), tunnel)


class ApproachTests(unittest.TestCase):
    def ledge(self):
        f = ActorFixture()
        f.entities[7]['origin'] = [200., 0., 76.]
        f.world.append((0, [184., -16., 0.], [216., 16., 40.]))
        return f

    def test_melee_region_uses_lower_supported_floor_instead_of_ledge_top(self):
        f = self.ledge()
        goal = [200., 0., 40.]
        f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, 10.)
        self.assertTrue(f.get('APPROACH_VALID'))
        self.assertAlmostEqual(goal[0], 130.)
        self.assertAlmostEqual(goal[1], 0.)
        self.assertEqual(goal[2], 0.)
        self.assertEqual(len(f.probes), 8)

    def test_region_cache_is_bounded_and_refreshes_when_target_moves(self):
        f = self.ledge()
        for now in (10., 10.1, 10.4):
            goal = [200., 0., 40.]
            f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, now)
        self.assertEqual(len(f.probes), 8)
        f.entities[7]['origin'][0] += 30.
        f.runtime.call('npc_melee_goal', 0, [0., 0., .1], [230., 0., 40.], 10.5)
        self.assertEqual(len(f.probes), 16)

    def test_unsupported_solid_or_occluded_positions_cannot_replace_goal(self):
        for restriction in ('support', 'hull', 'cover'):
            f = self.ledge()
            if restriction == 'support':
                f.support = False
            elif restriction == 'hull':
                f.hull_clear = False
            else:
                f.world.append((0, [176., -1000., 0.], [224., 1000., 200.]))
            goal = [200., 0., 40.]
            f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, 10.)
            with self.subTest(restriction=restriction):
                self.assertEqual(goal, [200., 0., 40.])
                self.assertFalse(f.get('APPROACH_VALID'))

    def test_stale_local_memory_and_ladder_preserve_original_destination(self):
        for restriction in ('memory', 'ladder', 'height'):
            f = self.ledge()
            if restriction == 'memory':
                f.values['gProfile'][0][f.values['ANPC_GLOBAL_HUNT']] = 0
            elif restriction == 'ladder':
                f.entities[7]['movetype'] = 5
            goal = [200., 0., 200. if restriction == 'height' else 40.]
            original = goal[:]
            f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, 10.)
            self.assertEqual(goal, original)
            self.assertEqual(f.probes, [])

    def test_failed_ledge_route_replans_to_attack_region_and_waits_with_idle(self):
        f = self.ledge()
        f.path_status = 3
        f.put('PATH_DESTINATION', [200., 0., 40.])
        f.put('PATH_AREA', -1)
        f.runtime.call('npc_animation', 0, 1, True)
        f.runtime.call('npc_hunt', 0, .05, 10.)
        self.assertEqual(f.rejected, [])
        self.assertEqual(f.requests[0][1][2], 0.)
        self.assertEqual(f.get('ANIMATION'), 0)

    def test_unreachable_nearest_attack_position_retries_other_samples(self):
        f = self.ledge()
        goal = [200., 0., 40.]
        f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, 10.)
        first = goal[:]
        f.put('PATH_DESTINATION', first)
        f.put('PATH_AREA', -1)
        f.path_status = 3
        f.runtime.call('npc_hunt', 0, .05, 10.1)
        self.assertEqual(f.rejected, [])
        self.assertNotEqual(f.requests[0][1], tuple(first))
        self.assertEqual(f.get('APPROACH_MASK'), 1)

    def test_failed_samples_do_not_reset_when_only_cache_time_expires(self):
        f = self.ledge()
        goal = [200., 0., 40.]
        f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, 10.)
        first = goal[:]
        f.runtime.call('npc_retry_melee_goal', 0, [0., 0., .1], goal, 10.1)
        goal = [200., 0., 40.]
        f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, 12.)
        self.assertNotEqual(goal, first)
        self.assertEqual(f.get('APPROACH_MASK'), 1)

    def test_all_attack_samples_are_finite_and_target_movement_resets_failures(self):
        f = self.ledge()
        goal, seen = [200., 0., 40.], set()
        f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, 10.)
        while f.get('APPROACH_VALID'):
            index = f.get('APPROACH_INDEX')
            self.assertNotIn(index, seen)
            seen.add(index)
            f.runtime.call('npc_retry_melee_goal', 0, [0., 0., .1], goal, 10.1)
        self.assertLessEqual(len(seen), 8)
        self.assertGreater(len(seen), 1)
        f.entities[7]['origin'][0] += 30.
        f.runtime.call('npc_melee_goal', 0, [0., 0., .1], [230., 0., 40.], 10.2)
        self.assertEqual(f.get('APPROACH_MASK'), 0)

    def test_close_alternative_is_not_discarded_while_waiting_for_repath_interval(self):
        f = self.ledge()
        f.world[1] = (0, [196., -4., 0.], [204., 4., 40.])
        f.values['gProfile'][0][f.values['ANPC_ATTACK_RANGE']] = 32.
        goal = [200., 0., 40.]
        f.runtime.call('npc_melee_goal', 0, [0., 0., .1], goal, 10.)
        f.put('PATH_DESTINATION', goal[:])
        f.put('PATH_AREA', -1)
        f.put('NEXT_REPATH', 10.6)
        f.path_status = 3
        for now in (10.1, 10.2, 10.3):
            f.runtime.call('npc_hunt', 0, .05, now)
            self.assertEqual(f.get('APPROACH_MASK'), 1)
            self.assertEqual(f.requests, [])
        f.runtime.call('npc_hunt', 0, .05, 10.6)
        self.assertEqual(len(f.requests), 1)
        self.assertEqual(f.get('APPROACH_MASK'), 1)


class LocalJumpTests(unittest.TestCase):
    def crate(self):
        f = ActorFixture()
        f.world.append((0, [80., -100., 0.], [160., 100., 64.]))
        return f

    def test_unrecorded_short_step_uses_real_ballistic_hull_proof(self):
        f = self.crate()
        self.assertTrue(f.runtime.call('npc_try_local_jump', 0, [0., 0., .1], [112., 0., 64.], 10.))
        self.assertFalse(f.entities[99]['flags'] & 512)
        self.assertGreater(f.entities[99]['velocity'][2], 0.)
        self.assertEqual(f.get('ANIMATION'), 3)
        self.assertGreater(f.trace_count, 10)

    def test_ceiling_or_wall_rejects_both_standing_and_air_duck_arcs(self):
        f = self.crate()
        f.world.append((0, [32., -100., 0.], [48., 100., 220.]))
        self.assertFalse(f.runtime.call('npc_try_local_jump', 0, [0., 0., .1], [112., 0., 64.], 10.))
        self.assertEqual(f.entities[99]['velocity'], [0., 0., 0.])

    def test_no_jump_capability_no_landing_and_wrong_floor_block_attempt(self):
        for restriction in ('capability', 'support', 'floor', 'distance', 'step', 'airborne'):
            f = self.crate()
            goal = [112., 0., 64.]
            if restriction == 'capability':
                f.values['gProfile'][0][f.values['ANPC_CAPABILITIES']] &= ~2
            elif restriction == 'support':
                f.support = False
            elif restriction == 'floor':
                goal[2] = 68.
            elif restriction == 'distance':
                goal[0] = 200.
            elif restriction == 'step':
                goal[2] = 18.
            else:
                f.entities[99]['flags'] = 0
            with self.subTest(restriction=restriction):
                self.assertFalse(f.runtime.call('npc_try_local_jump', 0, [0., 0., .1], goal, 10.))
                self.assertEqual(f.entities[99]['velocity'], [0., 0., 0.])

    def test_failed_probe_obeys_cooldown(self):
        f = self.crate()
        f.support = False
        for now in (10., 10.1, 10.3):
            self.assertFalse(f.runtime.call('npc_try_local_jump', 0, [0., 0., .1], [112., 0., 64.], now))
        self.assertEqual(len(f.probes), 1)
        f.runtime.call('npc_try_local_jump', 0, [0., 0., .1], [112., 0., 64.], 10.5)
        self.assertEqual(len(f.probes), 2)

    def test_shared_proof_budget_waits_without_rejecting_or_moving(self):
        f = self.crate()
        f.values.update(gLocalJumpTime=10., gLocalJumpTrials=2)
        self.assertTrue(f.runtime.call('npc_try_local_jump', 0, [0., 0., .1], [112., 0., 64.], 10.))
        self.assertEqual((f.trace_count, f.probes, f.rejected), (0, [], []))
        self.assertEqual(f.get('NEXT_JUMP_PROBE'), 0.)
        self.assertTrue(f.runtime.call('npc_try_local_jump', 0, [0., 0., .1], [112., 0., 64.], 10.05))


class StudioFixture:
    """File doubles expose decoded float cells to this non-VM interpreter."""
    def __init__(self, data):
        self.data, self.closed, self.fail_seek = data, 0, False
        v = self.values = dict(BLOCK_INT=4, BLOCK_CHAR=1, SEEK_SET=0)
        layout(v, (ROOT/'anpc_core.sma').read_text(encoding='utf-8-sig'), 'AnimationData')
        self.animation = [0]*v['AnimationData']
        self.file = io.BytesIO(data)
        self.float_offsets = set()
        if len(data) >= 172:
            count, offset = struct.unpack_from('<ii', data, 164)
            if 0 < count <= 4096:
                for sequence in range(count):
                    self.float_offsets.update(offset+sequence*176+k for k in (32, 76, 80, 84))
        r = self.runtime = PawnRuntime(v)
        common(r)
        r.bind('fopen', lambda *args: 1)
        r.bind('fclose', lambda file: setattr(self, 'closed', self.closed+1))
        r.bind('fseek', self.seek)
        r.bind('fread', self.read, (1,))
        r.bind('fread_blocks', self.read_blocks)
        r.bind('file_size', lambda name: len(data))
        r.bind('equal', lambda a, b: text(a) == text(b))
        r.bind('anpc_finite', lambda value, limit=16384.: math.isfinite(value) and abs(value) <= limit)
        r.load(source('studio.inc'), ('studio_sequence',))

    def seek(self, file, offset, whence):
        if self.fail_seek:
            return 1
        self.file.seek(offset, whence)
        return 0

    def read(self, file, out, mode):
        offset, raw = self.file.tell(), self.file.read(mode)
        if len(raw) != mode:
            return 0
        out.put(struct.unpack('<f' if offset in self.float_offsets else '<i', raw)[0])
        return 1

    def read_blocks(self, file, out, count, mode):
        read = 0
        for i in range(count):
            offset, raw = self.file.tell(), self.file.read(mode)
            if len(raw) < mode:
                break
            out[i] = raw[0] if mode == 1 else struct.unpack('<f' if offset in self.float_offsets else '<i', raw)[0]
            read += 1
        return read

    def query(self, label):
        return self.runtime.call('studio_sequence', 'model.mdl', label, self.animation)


class StudioTests(unittest.TestCase):
    def descriptor(self, fps=30., frames=31, motion=(120., 0., 0.)):
        data = bytearray(244+176)
        struct.pack_into('<ii', data, 0, 0x54534449, 10)
        struct.pack_into('<ii', data, 164, 1, 244)
        data[244:247] = b'run'
        struct.pack_into('<fi', data, 244+32, fps, 1)
        struct.pack_into('<i', data, 244+56, frames)
        struct.pack_into('<3f', data, 244+76, *motion)
        return data

    def test_model_rate_duration_and_linear_ground_speed_are_read_from_binary(self):
        f = StudioFixture(self.descriptor())
        self.assertTrue(f.query('run'))
        self.assertEqual(f.animation[f.values['ANIM_RATE']], 256.)
        self.assertEqual(f.animation[f.values['ANIM_GROUND_SPEED']], 120.)
        self.assertEqual(f.closed, 1)

    def test_default_model_attack_loop_flag_is_present_and_known(self):
        data = (ROOT.parents[1]/'resources/models/player/zpn_z_default/zpn_z_default.mdl').read_bytes()
        f = StudioFixture(data)
        self.assertTrue(f.query('ref_shoot_knife'))
        self.assertTrue(f.animation[f.values['ANIM_LOOP']])
        self.assertAlmostEqual(f.animation[f.values['ANIM_RATE']], 153.6)

    def test_invalid_header_offsets_nan_and_truncation_are_rejected(self):
        for corruption in ('magic', 'offset', 'count', 'fps', 'motion', 'frames', 'short'):
            data = self.descriptor()
            if corruption == 'magic':
                struct.pack_into('<i', data, 0, 0)
            elif corruption == 'offset':
                struct.pack_into('<i', data, 168, 100000)
            elif corruption == 'count':
                struct.pack_into('<i', data, 164, 4097)
            elif corruption == 'fps':
                struct.pack_into('<f', data, 244+32, float('nan'))
            elif corruption == 'motion':
                struct.pack_into('<f', data, 244+76, float('nan'))
            elif corruption == 'frames':
                struct.pack_into('<i', data, 244+56, 1)
            else:
                data = data[:180]
            f = StudioFixture(data)
            with self.subTest(corruption=corruption):
                self.assertFalse(f.query('run'))
                self.assertEqual(f.closed, 1)

    def test_failed_seek_and_missing_label_close_file(self):
        for failure in ('seek', 'label'):
            f = StudioFixture(self.descriptor())
            f.fail_seek = failure == 'seek'
            self.assertFalse(f.query('absent' if failure == 'label' else 'run'))
            self.assertEqual(f.closed, 1)


class ViewerFixture:
    def __init__(self):
        code = (ROOT/'anpc_admin.sma').read_text(encoding='utf-8-sig')
        v = self.values = {}
        for key in ('NAV_SHOW_NODES', 'NAV_SHOW_LINKS', 'NAV_SHOW_AREAS', 'NAV_SHOW_BATCH'):
            v[key] = int(re.search(r'#define '+key+r'\s+(\d+)', code)[1])
        v.update(NAV_SHOW_BEAMS=v['NAV_SHOW_NODES']+v['NAV_SHOW_LINKS']+v['NAV_SHOW_AREAS']*4,
                 NAV_SHOW_INTERVAL=.5, NAV_SHOW_RANGE=5000., NAV_SHOW_CONE_COS=.5,
                 NAV_SHOW_LIFT=2., NAV_SHOW_NODE_HEIGHT=20., NAV_SHOW_BEAM_WIDTH=10,
                 MaxClients=32, FMRES_IGNORED=1, MSG_ONE_UNRELIABLE=1, SVC_TEMPENTITY=23,
                 TE_BEAMPOINTS=0, EngFunc_WriteCoord=1, gBeamSprite=1, xMsgSyncANPC=1,
                 ANPC_NODE_LADDER=2, ANPC_NODE_DISABLED=4, ANPC_NODE_PORTAL=8)
        v['_'] = 0  # Pawn's omitted/default native argument.
        beam_size = layout(v, code, 'NavShowBeam')
        v.update(gShow=[False]*33, gShowCount=[0]*33, gShowCursor=[0]*33,
                 gNextShow=[0.]*33, gNextBeamBatch=0.,
                 gShowBeam=[[[0]*beam_size for _ in range(v['NAV_SHOW_BEAMS'])] for _ in range(33)])
        self.now, self.connected, self.builds, self.sent, self.messages = 10., {1, 2}, [], [], []
        self.hud, self.generated = [], v['NAV_SHOW_BEAMS']
        r = self.runtime = PawnRuntime(v)
        common(r)
        r.bind('get_gametime', lambda: self.now)
        r.bind('is_user_connected', lambda id: id in self.connected)
        r.bind('show_nodes', self.build)
        r.bind('admin_send_beam', lambda id, index: self.sent.append((id, index, self.now)))
        r.bind('set_hudmessage', lambda *args: self.hud.append(args))
        r.bind('ShowSyncHudMsg', lambda *args: None)
        r.bind('anpc_nav_editing', lambda: False)
        r.bind('anpc_nav_count', lambda: 0)
        r.bind('anpc_nav_area_count', lambda: 1)
        r.bind('admin_nav_view', lambda id, eye, direction:
               (eye.__setitem__(slice(None), [72., 72., 100.]), direction.__setitem__(slice(None), [1., 0., 0.])))
        r.bind('anpc_nav_area', self.area, (4,))
        r.bind('message_begin', lambda *args: self.messages.append(('begin', args)))
        r.bind('message_end', lambda: self.messages.append(('end',)))
        r.bind('write_byte', lambda value: self.messages.append(('byte', value)))
        r.bind('write_short', lambda value: self.messages.append(('short', value)))
        r.bind('engfunc', lambda op, value: self.messages.append(('coord', value)))
        r.load(code, ('admin_beam', 'nav_show_frame', 'admin_nav_in_view', 'client_disconnected'))

    def build(self, id):
        self.builds.append((id, self.now))
        for index in range(self.generated):
            self.runtime.call('admin_beam', id, [float(index), 0., 0.], [float(index), 0., 20.], 40, 100)

    @staticmethod
    def area(id, lo, hi, normal, flags):
        lo[:], hi[:], normal[:] = [-128., -128., 0.], [128., 128., 0.], [0., 0., 1.]
        flags.put(0)
        return True

    def tick(self, now):
        self.now = now
        self.runtime.call('nav_show_frame')


class ViewerTests(unittest.TestCase):
    def test_beam_queue_capacity_and_native_packet_fields(self):
        f = ViewerFixture()
        f.generated = 100
        f.build(1)
        self.assertEqual(f.values['gShowCount'][1], 32)
        self.assertEqual(f.values['gShowBeam'][1][31][:6], [31., 0., 0., 31., 0., 20.])
        f.values.update(SHOW_FROM=0, SHOW_TO=3)
        f.runtime.load((ROOT/'anpc_admin.sma').read_text(encoding='utf-8-sig'), ('admin_send_beam',))
        f.runtime.call('admin_send_beam', 1, 31)
        self.assertEqual([item[1] for item in f.messages if item[0] == 'coord'], [31., 0., 0., 31., 0., 20.])
        self.assertEqual(sum(item[0] == 'begin' for item in f.messages), 1)
        self.assertEqual(sum(item[0] == 'end' for item in f.messages), 1)

    def test_each_viewer_gets_small_batches_and_rebuilds_after_half_second(self):
        f = ViewerFixture()
        f.values['gShow'][1] = f.values['gShow'][2] = True
        f.tick(10.)
        self.assertEqual(len(f.sent), 8)
        f.tick(10.02)
        self.assertEqual(len(f.sent), 8)
        for tick in range(1, 11):
            f.tick(10.+tick*.051)
        self.assertEqual(len(f.builds), 4)
        self.assertEqual(f.builds[2:][0][1], 10.51)
        for id in (1, 2):
            first = [index for who, index, time in f.sent if who == id and time < 10.5]
            self.assertEqual(first, list(range(32)))

    def test_empty_view_self_refreshes_and_disabled_clients_send_nothing(self):
        f = ViewerFixture()
        f.generated = 0
        f.values['gShow'][1] = True
        f.tick(10.)
        f.tick(10.6)
        self.assertEqual(f.builds, [(1, 10.), (1, 10.6)])
        self.assertEqual(f.sent, [])
        f.values['gShow'][1] = False
        f.tick(11.2)
        self.assertEqual(len(f.builds), 2)

    def test_disconnect_clears_toggle_and_queued_points_before_slot_reuse(self):
        f = ViewerFixture()
        f.values.update(gRecorder=0, TASK_RECORD=7900, gRecordedNode=-1)
        f.values['gShow'][1] = True
        f.tick(10.)
        f.runtime.call('client_disconnected', 1)
        f.tick(11.)
        self.assertFalse(f.values['gShow'][1])
        self.assertEqual(f.values['gShowCount'][1], 0)
        self.assertEqual(len(f.sent), 4)

    def test_low_fps_drains_queue_before_replacing_it(self):
        f = ViewerFixture()
        f.values['gShow'][1] = True
        for tick in range(8):
            f.tick(10.+tick*.2)
        self.assertEqual(len(f.builds), 1)
        self.assertEqual([index for id, index, now in f.sent], list(range(32)))
        f.tick(11.6)
        self.assertEqual(len(f.builds), 2)

    def test_current_area_is_visible_without_anchors_and_hud_has_hold_time(self):
        f = ViewerFixture()
        f.values['gShow'][1] = True
        f.runtime.load((ROOT/'anpc_admin.sma').read_text(encoding='utf-8-sig'), ('show_nodes',))
        f.tick(10.)
        self.assertEqual(f.values['gShowCount'][1], 4)
        self.assertGreater(f.hud[0][7], .5)
        self.assertEqual(len(f.sent), 4)


if __name__ == '__main__':
    unittest.main()
