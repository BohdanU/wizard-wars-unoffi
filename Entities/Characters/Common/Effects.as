// Listener file for different effects, spells and operations that can't be
// utilized through StatusEffects.as and with adding an own script
// onHit() inputs 0 damage entry in an added script
// everything else that would go in additional script is added here as well

#include "Hitters.as"

Random _sprk_r2(12345);

f32 connection_dist = 256.0f;
f32 connection_dmg_reduction = 0.33f;
f32 min_connection_health_ratio = 0.25f;

void onInit(CBlob@ this)
{
    this.set_f32("majestyglyph_cd_reduction", 1.0f);
}

void onTick(CBlob@ this)
{
    if (getMap() is null) return;

    if (isClient())
    {
        CSprite@ sprite = this.getSprite();
        if (sprite is null) return;

        if (this.get_u16("dmgconnection") > 0) // spiritual connection
        {
            CBlob@ link = getBlobByNetworkID(this.get_u16("dmgconnection_id"));
            if (link !is null && this.getDistanceTo(link) < connection_dist
                && link.getHealth()/link.getInitialHealth() > min_connection_health_ratio)
            {
                Vec2f dir = link.getPosition() - this.getPosition();
                Vec2f norm_dir = dir;
                norm_dir.Normalize();
                for (uint step = 0; step < dir.Length(); step += 16)
		    	{
		    		ConnectionSparks(this.getPosition() + norm_dir*step, 1, norm_dir*4.0f * (1.25f - step/dir.Length()));
		    	}
            }
        }

        if (this.get_u16("hallowedbarrier") > 0) // hallowed barrier, spinning shields
        {
            u8 initamount = this.get_u8("hallowedbarriermax");
            u8 amount = this.get_u8("hallowedbarrieramount");

            if (amount > 0)
            {
                f32 inline_width = 20;
                f32 gap = inline_width / amount;

                for (u8 i = 0; i < amount; i++)
                {
                    CSpriteLayer@ l = sprite.getSpriteLayer("hallowedbarrier_segment"+i);
                    if (l is null)
                    {
                        @l = sprite.addSpriteLayer("hallowedbarrier_segment"+i, "ShieldSegment.png", 16, 16);
                        if (l !is null)
                        {
                            Animation@ anim = l.addAnimation("default", 0, false);
                            if (anim !is null)
                            {
                                int[] frames = {0,1,2,3,4};
                                anim.AddFrames(frames);
                                l.SetAnimation(anim);
                                l.SetIgnoreParentFacing(true);

                                Vec2f sort = Vec2f(inline_width/2 - gap/2 - gap*i, 0);
                                l.SetOffset(sort);
                            }
                        }
                    }

                    if (l !is null)
                    {
                        Vec2f offset = l.getOffset();
                        bool onleft = offset.x <= 0;
                        f32 dist = Maths::Abs(offset.x);
                        u8 frame = dist > inline_width/4 ? 2 : dist > inline_width/8 ? 1 : 0;
                        if (frame > 0 && onleft) frame += 2;

                        //l.SetFacingLeft(onleft);
                        l.animation.frame = frame;
                        l.SetRelativeZ(10.0f + inline_width-dist);
                        l.setRenderStyle(RenderStyle::additive);

                        f32 target = -inline_width/2;

                        Vec2f new_offset = l.getOffset();
                        f32 prox = calc_proximity(target, 0, -target, new_offset.x);

                        l.SetOffset(new_offset-Vec2f(Maths::Max(0.1f, 2.0f * prox), 0));

                        if (new_offset.x < target)
                        {
                            new_offset.x = -target;
                            l.SetOffset(new_offset);
                        }
                    }
                }
            }
        }
    }
}

f32 calc_proximity(f32 a, f32 b, f32 max, f32 e)
{
    if (a > max || b > max || a > b) return 0.0f;
    if (a < 0)
    {b -= a; e -= a; a = 0;}

    if (b < 0)
    {a -= b; e -= b; b = 0;}

    if (e < 0) return Maths::Max(0.0f, Maths::Min(1.0f, (b + e) / max));

    f32 distanceToA = Maths::Abs(e - a);
    f32 distanceToB = Maths::Abs(e - b);
    f32 maxDistance = Maths::Abs(b - a);

    f32 normalizedDistance = 1.0f - (distanceToB / maxDistance);
    return Maths::Max(0.0f, Maths::Min(1.0f, normalizedDistance));
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
    if (!this.hasTag("dead"))
    {
        if (customData != Hitters::burn && customData != Hitters::fall //&& hitterBlob.getTeamNum() == this.getTeamNum()
            && this.get_u16("hallowedbarrier") > 0)
        {
            u8 initamount = this.get_u8("hallowedbarriermax");
            u8 amount = this.get_u8("hallowedbarrieramount");
            u8 missing = initamount-amount;

            if (damage > 0.05f && amount > 0)
            {
                if (isClient())
                {
                    this.sub_u8("hallowedbarrieramount", 1);

                    string n = "hallowedbarrier_segment"+(amount-1);
                    CSpriteLayer@ pop = this.getSprite().getSpriteLayer(n);
                    if (pop !is null)
                    {
                        ParticlesFromSprite(pop, pop.getWorldTranslation(), Vec2f(0, -0.75f).RotateBy(XORRandom(360)), 0, 3);
					    this.getSprite().RemoveSpriteLayer(n);
                    }
                }
                if (isServer())
                {
                    damage *= 0.5f;
                }
            }
        }

        if (this.get_u16("dmgconnection") > 0 && this.get_u16("dmgconnection_id") != 0)
        {
            if (isClient())
            {

            }
            if (isServer())
            {
                CBlob@ link = getBlobByNetworkID(this.get_u16("dmgconnection_id"));
                if (link !is null && this.getDistanceTo(link) < connection_dist
                    && link.getHealth()/link.getInitialHealth() > min_connection_health_ratio)
                {
                    f32 dmg = damage*connection_dmg_reduction;
                    if (hitterBlob !is null)
                    {
                        hitterBlob.server_Hit(link, link.getPosition(), Vec2f_zero, dmg, Hitters::fall, true);
                    }
                    else
                        this.server_Hit(link, link.getPosition(), Vec2f_zero, dmg, Hitters::fall, true);

                    damage *= (1.0f - connection_dmg_reduction);
                }
            }
        }
    }

    return damage;
}

void ConnectionSparks(Vec2f pos, int amount, Vec2f pushVel = Vec2f(0,0))
{
	for (int i = 0; i < amount; i++)
    {
        Vec2f vel(_sprk_r2.NextFloat() * 1.0f, 0);
        vel.RotateBy(_sprk_r2.NextFloat() * 360.0f);

        CParticle@ p = ParticlePixelUnlimited( pos, vel + pushVel, SColor(255, 180+XORRandom(40), 180+XORRandom(50), XORRandom(175)), true);
        if(p is null) return; //bail if we stop getting particles

        p.collides = false;
        p.fastcollision = true;
        p.bounce = 0.0f;
        p.timeout = 8 + _sprk_r2.NextRanged(20);
        p.scale = 0.5f + _sprk_r2.NextFloat();
        p.damping = 0.95f;
		p.gravity = Vec2f(0,0);
    }
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
    if (!isServer()) return;
    if (oldHealth < this.getHealth() && this.get_u16("healblock") > 0)
    {
        this.server_SetHealth(oldHealth);
    }
}