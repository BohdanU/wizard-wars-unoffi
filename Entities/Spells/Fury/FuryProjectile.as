#include "Hitters.as";
#include "SpellCommon.as";

void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = true;
	consts.bullet = true;
	shape.SetGravityScale(0.0f);

	this.Tag("projectile");
	this.Tag("counterable");
	this.Tag("die_in_divine_shield");
	if (!this.exists("damage")) this.set_f32("damage", 0.5f);

	this.getSprite().SetZ(9.0f);

    //dont collide with top of the map
	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);

	CSprite@ sprite = this.getSprite();
	sprite.setRenderStyle(RenderStyle::additive);
    sprite.RotateBy(-135, Vec2f_zero);
}

void onTick(CBlob@ this)
{
    if (isServer()) this.setVelocity(this.getVelocity() * this.get_f32("damping"));
    this.setAngleDegrees(-this.getOldVelocity().Angle());
    
	if (this.getTickSinceCreated()==0)
	{
		// sound goes here
	}

    if (isServer())
    {
        for (u8 i = 0; i < getPlayersCount(); i++)
        {
            CPlayer@ p = getPlayer(i);
            if (p is null) continue;
            CBlob@ b = p.getBlob();
            if (b is null || b.getTeamNum() == this.getTeamNum()) continue;
            if (b.getDistanceTo(this) < 80.0f)
            {
                Vec2f dir = b.getPosition()-this.getPosition();
                dir.Normalize;
                this.AddForce(dir * 0.25f);
                this.server_SetTimeToDie(2);
            }
        }
    }

	CMap@ map = getMap();
	if (map is null)
	{return;}

	if(!isClient())
	{return;}

	if (getGameTime()%2==0)
	{
		for(int i = 0; i < 3; i ++)
		{
			float randomPVel = XORRandom(11) * 0.01f - 0.5f;
			Vec2f particleVel = Vec2f(randomPVel, 0).RotateBy(XORRandom(721));

    		CParticle@ p = ParticlePixelUnlimited(this.getPosition()+Vec2f(-3, 0).RotateByDegrees(this.getAngleDegrees()), particleVel, SColor(255,255,75+XORRandom(76),XORRandom(51)), true);
   			if(p !is null)
    		{
    		    p.collides = false;
    		    p.gravity = Vec2f_zero;
    		    p.bounce = 1;
    		    p.lighting = false;
    		    p.timeout = 5+XORRandom(6);
				p.damping = 0.95f;
    		}
		}
	}
}

void onCollision( CBlob@ this, CBlob@ blob, bool solid )
{
	if (this.getTickSinceCreated() < 3) return;
	if (blob !is null && this !is null)
	{
		if (isEnemy(this, blob) && !this.hasTag("dead"))
		{
			this.Tag("dead");
            this.server_Hit(blob, blob.getPosition(), Vec2f(0,-0.69f), this.get_f32("damage"), Hitters::arrow, false);
			this.server_Die();
		}
	}
    else if (solid)
    {
        this.server_Die();
    }
}

bool isEnemy( CBlob@ this, CBlob@ target )
{
	return 
	(
		(
			target.hasTag("barrier") || (target.hasTag("flesh") && !target.hasTag("dead") )
		)
		&& target.getTeamNum() != this.getTeamNum() 
	);
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return isEnemy(this, blob);
}