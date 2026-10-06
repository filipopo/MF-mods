//=============================================================================
// Totem - Hybrid Totem of Undying & Tactical Restoration Stim
//
// 1. Passive Cheat-Death: Intercepts fatal blows, leaving player at
//    SurviveHealth (5 HP), gives 1.0s invulnerability and emergency recovery HoT.
// 2. Primary Fire (LMB): AoE Pulse Heal (+55 HP to user and friendlies in 400 radius).
// 3. Secondary Fire (RMB): Targeted HoT injection on a teammate (+120 HP over 10s).
// 4. Reload (R): Dedicated self-cast for full sustained HoT (+120 HP over 10s).
//=============================================================================
class Totem extends RageWeapon;

var int SurviveHealth;
var int AoEHealAmount;
var float AoERadius;
var int HoTHealPerTick;
var int HoTTicks;
var float HoTInterval;
var int ReviveHoTHealPerTick;
var int ReviveHoTTicks;
var float ReviveGracePeriod;
var float TraceRange;

// Viewmodel animation stubs (suppresses unassigned 3D mesh sequences)
simulated function PlaySelect() {}
simulated function PlaySelectAnim() {}
simulated function PlayTweenDownAnim() {}
simulated function PlayIdleAnim() {}
simulated function Timer() {}
simulated function PlayZoomedInIdleAnim() {}
simulated function PlayAimDownAnim() {}
simulated function PlayAimUpAnim() {}
simulated function PlayAltFiringAnim() {}
simulated function PlayFiringAnim() {}
simulated function PlayReloadingAnim() {}
simulated function PlayTweenToStillAnim() {}

simulated function String GetAmmoStatus()
{
    return String(ClipAmmo);
}

function bool IsFriendly(Pawn Target)
{
    if (Target == None || Pawn(Owner) == None)
        return false;
    if (Target == Owner)
        return true;
    if (Level.Game.bTeamGame && Target.PlayerReplicationInfo != None)
        return (Pawn(Owner).PlayerReplicationInfo.Team == Target.PlayerReplicationInfo.Team);
    return false;
}

//=============================================================================
// Passive Cheat-Death
//=============================================================================

function int ArmorAbsorbDamage(int Damage, name DamageType, vector HitLocation)
{
    local int AllowedDamage;
    local Pawn P;

    // Ignore zero-damage calls (zone transitions send ReduceDamage(0, 'Breathe'))
    // and unblockable damage types
    if (Damage <= 0 || DamageType == 'Suicided' || DamageType == 'Crushed')
        return Damage;

    P = Pawn(Owner);
    if (P != None && P.Health > 0 && Damage >= P.Health)
    {
        if (P.Health > SurviveHealth)
            AllowedDamage = P.Health - SurviveHealth;
        else
            AllowedDamage = 0;

        TriggerRevival(HitLocation);
        return AllowedDamage;
    }

    return Damage;
}

function TriggerRevival(vector HitLocation)
{
    local TotemHealEffect Buff;
    local Pawn P;

    P = Pawn(Owner);
    if (P == None)
        return;

    Buff = Spawn(class'TotemHealEffect', P);
    if (Buff != None)
    {
        // GiveTo first (settles the actor into inventory + Idle2 state),
        // THEN ActivateBuff (starts the timer safely after state transition)
        Buff.GiveTo(P);
        Buff.ActivateBuff(ReviveHoTHealPerTick, ReviveHoTTicks, HoTInterval, ReviveGracePeriod);
    }

    if (PlayerPawn(P) != None)
    {
        PlayerPawn(P).ClientInstantFlash(-0.6, vect(1000, 850, 200));
        PlayerPawn(P).ClientMessage("Totem of Undying triggered! Death prevented.");
    }

    P.PlayOwnedSound(Sound'MiscSFX.ArmourWearOut', SLOT_Misc, P.SoundDampening * 2.0);

    UseAmmo(1);
    if (ClipAmmo <= 0)
    {
        bIsAnArmor = false;
        Destroy();
    }
}

//=============================================================================
// Primary Fire: AoE Pulse Heal
//=============================================================================

function Fire(float Value)
{
    if (Pawn(Owner) != None && Pawn(Owner).CanFire() && AmmoInClip())
    {
        bPointing = True;
        bCanClientFire = True;
        PulseHeal();
    }
}

function PulseHeal()
{
    local Pawn P;
    local int TargetsHealed;

    if (Pawn(Owner) == None)
        return;

    // Count how many targets actually need healing
    TargetsHealed = 0;

    if (ApplyInstantHeal(Pawn(Owner), AoEHealAmount))
        TargetsHealed++;

    foreach VisibleCollidingActors(class'Pawn', P, AoERadius, Pawn(Owner).Location)
    {
        if (P != None && P != Owner && P.Health > 0 && IsFriendly(P))
        {
            if (ApplyInstantHeal(P, AoEHealAmount))
                TargetsHealed++;
        }
    }

    // Don't consume ammo if nobody actually needed healing
    if (TargetsHealed == 0)
    {
        if (PlayerPawn(Owner) != None)
            PlayerPawn(Owner).ClientMessage("No one needs healing.");
        return;
    }

    if (PlayerPawn(Owner) != None)
    {
        PlayerPawn(Owner).ClientInstantFlash(0.35, vect(200, 1000, 400));
        PlayerPawn(Owner).ClientMessage("AoE Pulse Heal activated! (" $ TargetsHealed $ " healed)");
    }

    Owner.PlaySound(Sound'MiscSFX.ArmourWearOut', SLOT_Misc, Pawn(Owner).SoundDampening);

    UseAmmo(1);
    if (!AmmoInClip())
        ConsumeWeapon();
}

// Returns true if target was actually healed
function bool ApplyInstantHeal(Pawn Target, int Amount)
{
    if (Target != None && Target.Health > 0 && Target.Health < Target.Default.Health)
    {
        Target.Health = Min(Target.Default.Health, Target.Health + Amount);
        Target.PlaySound(Target.HitSound2, SLOT_Talk, 0.6);
        return true;
    }
    return false;
}

//=============================================================================
// Secondary Fire: Targeted Ally HoT
//=============================================================================

function AltFire(float Value)
{
    if (Pawn(Owner) != None && Pawn(Owner).CanFire() && AmmoInClip())
    {
        bPointing = True;
        bCanClientFire = True;
        TryTargetedHoT();
    }
}

function TryTargetedHoT()
{
    local vector HitLocation, HitNormal, EndTrace, X, Y, Z, Start;
    local actor Other;

    Owner.MakeNoise(Pawn(Owner).SoundDampening);
    GetAxes(Pawn(Owner).ViewRotation, X, Y, Z);
    Start = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
    AdjustedAim = Pawn(Owner).AdjustAim(1000000, Start, AimError, False, False);
    EndTrace = Owner.Location + (TraceRange * vector(AdjustedAim));
    Other = Pawn(Owner).TraceShot(HitLocation, HitNormal, EndTrace, Start);

    if (Other != None && Other.bIsPawn && Pawn(Other) != Owner && IsFriendly(Pawn(Other)))
    {
        if (Pawn(Other).Health >= Pawn(Other).Default.Health)
        {
            if (PlayerPawn(Owner) != None)
                PlayerPawn(Owner).ClientMessage("Target is already at full health.");
            return;
        }
        ApplyFullHoT(Pawn(Other));
        UseAmmo(1);
        if (!AmmoInClip())
            ConsumeWeapon();
    }
}

//=============================================================================
// Reload: Self HoT
//=============================================================================

function Reload()
{
    if (AmmoInClip() && Pawn(Owner) != None && Pawn(Owner).CanFire())
    {
        if (Pawn(Owner).Health >= Pawn(Owner).Default.Health)
        {
            if (PlayerPawn(Owner) != None)
                PlayerPawn(Owner).ClientMessage("Already at full health.");
            return;
        }
        ApplyFullHoT(Pawn(Owner));
        UseAmmo(1);
        if (!AmmoInClip())
            ConsumeWeapon();
    }
}

//=============================================================================
// Full HoT Buff Applicator
//=============================================================================

function ApplyFullHoT(Pawn Target)
{
    local TotemHealEffect Buff;

    Buff = Spawn(class'TotemHealEffect', Target);
    if (Buff != None)
    {
        // GiveTo first, THEN ActivateBuff (same pattern as TriggerRevival)
        Buff.GiveTo(Target);
        Buff.ActivateBuff(HoTHealPerTick, HoTTicks, HoTInterval, 0.0);
    }

    if (Target == Owner)
    {
        if (PlayerPawn(Owner) != None)
        {
            PlayerPawn(Owner).ClientInstantFlash(0.4, vect(200, 600, 1000));
            PlayerPawn(Owner).ClientMessage("Sustained Regeneration activated.");
        }
    }
    else
    {
        if (PlayerPawn(Owner) != None)
            PlayerPawn(Owner).ClientMessage("Injected ally with Sustained Regeneration!");
        if (PlayerPawn(Target) != None)
            PlayerPawn(Target).ClientMessage("Ally injected you with Sustained Regeneration!");
    }

    Target.PlaySound(Target.HitSound2, SLOT_Talk, 0.8);
}

//=============================================================================
// Weapon Consumption & State Transitions
//=============================================================================

// Clean removal: switch to best weapon, then destroy so no HUD ghost remains
function ConsumeWeapon()
{
    bIsAnArmor = false;
    if (Pawn(Owner) != None)
        Pawn(Owner).SwitchToBestWeapon();
    GotoState('DownWeapon');
}

state DownWeapon
{
ignores Fire, AltFire;
Begin:
    Pawn(Owner).ChangedWeapon();
    if (!AmmoInClip())
        Destroy();
}

function Finish()
{
    if (!AmmoInClip())
    {
        ConsumeWeapon();
        return;
    }
    GotoState('Idle');
}

simulated function ClientFinish()
{
    if (!AmmoInClip())
    {
        if (PlayerPawn(Owner) != None)
            PlayerPawn(Owner).SwitchToBestWeapon();
        return;
    }
    Super.ClientFinish();
}

defaultproperties
{
     SurviveHealth=5
     AoEHealAmount=55
     AoERadius=400.000000
     HoTHealPerTick=6
     HoTTicks=20
     HoTInterval=0.500000
     ReviveHoTHealPerTick=3
     ReviveHoTTicks=6
     ReviveGracePeriod=1.000000
     TraceRange=150.000000
     AIRating=-1.000000
     NameColor=(R=255,G=215)
     MaxCanCarry=1
     CarrySize=2
     MaxClipAmmo=1
     MaxClips=1
     bDestroyWhenEmpty=True
     WeaponIcon=(X=144,W=48,H=64,t=Texture'RageWeapons.WeaponIcons')
     bCanThrow=False
     bOwnsCrosshair=True
     AutoSwitchPriority=0
     InventoryGroup=10
     PickupMessage="Loaded up Totem of Undying."
     ItemName="Totem of Undying"
     bIsAnArmor=True
     AbsorptionPriority=1
}
