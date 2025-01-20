/*
	Shot UnderWater Module - Enables or disables the ability for specified weapons to fire underwater.
*/

/*
	Copyright (C) 2024  WATCH_DOGS UNITED
*/

/*
	This program is designed to work with AMX Mod X and the GoldSrc engine,
	which is owned and licensed by Valve Software. This program is not
	endorsed or sponsored by Valve Software, and Valve Software is not
	responsible for any issues or errors that may arise from the use
	of this program.
*/

/*
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program. If not, see <https://www.gnu.org/licenses/>.
*/

/*
	This program was written based on the 'Updated HL1 SDK for the October 2, 2024 Steam patch' and
	entirely by WATCH_DOGS UNITED without the use of AI or automated code generation tools.
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

const g_bNoShot = (( 1 << CSW_NONE ) | ( 1 << CSW_GLOCK ) | ( 1 << CSW_HEGRENADE ) | ( 1 << CSW_C4 ) | ( 1 << CSW_SMOKEGRENADE ) | ( 1 << CSW_FLASHBANG ) | ( 1 << CSW_KNIFE ));

const g_bShootsUnderWater = ( 0xFFFFFFFF ^ ( g_bNoShot | ( 1 << CSW_XM1014 ) | ( 1 << CSW_GALIL ) | ( 1 << CSW_FAMAS ) | ( 1 << CSW_M3 )) );

const MAX_COMMAND_STRING_LENGHT = 64;

new const Float:g_vecZero[ 3 ] = { 0.0, 0.0, 0.0 };

new const g_szEvents[ ][ ] =
{
	"",
	"",
	"",
	"",
	"",
	"events/xm1014.sc",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"events/galil.sc",
	"events/famas.sc",
	"",
	"",
	"",
	"",
	"",
	"events/m3.sc",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	""
}

new const g_szWeapon[ CSW_P90 + 1 ][ ] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550", "weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249", "weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552", "weapon_ak47", "weapon_knife", "weapon_p90" }

new const g_szDryfireSound[ CSW_GLOCK ][ ] = { "weapons/dryfire_rifle.wav", "weapons/dryfire_pistol.wav" }

new HamHook:p_Item_PostFrame[ CSW_P90 + 1 ];

new g_m_usGunEvents[ CSW_P90 + 1 ];
new g_bRelease[ CSW_P90 + 1 ];

new g_iWpn[ MAX_PLAYERS + 1 ];

new Float:g_flTimeLast[ MAX_PLAYERS + 1 ];

new p_UpdateClientData;

new g_m_iId;
new g_m_iClip;
new g_iShooter;

new g_bShotUnderWater;
new g_bFaked;
new g_bPrediction;
new g_bConnected;
new g_bBot;
new g_bInWater;
new g_bNoPredict;

public plugin_init( )
{
	register_plugin( "Shot UnderWater", "1.01", "WATCH_DOGS UNITED" );

	if ( !engfunc( EngFunc_FindEntityByString, ( MAX_PLAYERS + 1 ), "classname", "func_water" ) )
	{
		pause( "d" );
	}

	new szTemp[ PLATFORM_MAX_PATH ];

	const maxchars = charsmax( szTemp );

	get_configsdir( szTemp, maxchars );

	new szMapName[ MAX_COMMAND_STRING_LENGHT ];

	get_mapname( szMapName, charsmax( szMapName ) );

	formatex( szTemp, maxchars, "%s/shot_underwater/%s.ini", szTemp, szMapName );

	new iFilePtr = fopen( szTemp, "r" );

	if ( !iFilePtr )
	{
		replace( szTemp, maxchars, szMapName, "shot_underwater" );

		iFilePtr = fopen( szTemp, "r" );
	}

	if ( iFilePtr )
	{
		new iLen, i;

		while ( fgets( iFilePtr, szTemp, maxchars ) )
		{
			trim( szTemp );

			iLen = strlen( szTemp );

			szTemp[ ( iLen - 2 ) ] = 0;

			trim( szTemp );

			i = CSW_NONE;

			while ( ++i < HLW_SUIT )
			{
				if ( !( g_bNoShot & ( 1 << i ) ) && equal( szTemp, g_szWeapon[ i ][ 7 ] ) )
				{
					g_bShotUnderWater |= ( str_to_num( szTemp[ ( iLen - 1 ) ] ) << i );
				}
			}
		}

		fclose( iFilePtr );
	}

	else
	{
		server_print( "^n[ Shot UnderWater ]: Missing Config. File.^n[ Shot UnderWater ]: Guns Won't Shoot Underwater!^n" );
	}

	new i = HLW_SUIT;

	while ( --i > CSW_NONE )
	{
		if ( ( g_bShotUnderWater & ( 1 << i ) ) ^ ( g_bShootsUnderWater & ( 1 << i ) ) )
		{
			RegisterHam( Ham_Weapon_PrimaryAttack, g_szWeapon[ i ], "fw_Weapon_PrimaryAttack",      .Post = false );
			RegisterHam( Ham_Weapon_PrimaryAttack, g_szWeapon[ i ], "fw_Weapon_PrimaryAttack_Post", .Post = true );

			RegisterHam( Ham_Item_Deploy, g_szWeapon[ i ], "fw_Item_Deploy_Post", .Post = true );

			if ( g_bShootsUnderWater & ( 1 << i ) )
			{
				RegisterHam( Ham_Item_Holster, g_szWeapon[ i ], "fw_Item_Holster_Post", .Post = true );

				p_Item_PostFrame[ i ] = RegisterHam( Ham_Item_PostFrame, g_szWeapon[ i ], "fw_Item_PostFrame", .Post = false );

				DisableHamForward( p_Item_PostFrame[ i ] );
			}
		}
	}

	register_forward( FM_PrecacheEvent, "fw_PrecacheEvent_Post", ._post = true );

	register_forward( FM_ClientDisconnect, "fw_Client_Disconnect", ._post = false );

	register_forward( FM_ClientUserInfoChanged, "fw_ClientUserInfoChanged", ._post = false );
}

public fw_PrecacheEvent_Post( const type, const psz[ ] )
{
	if ( type == 1 )
	{
		new i = CSW_M4A1;

		while ( --i > CSW_HEGRENADE )
		{
			if ( !( g_bNoShot & ( 1 << i ) ) && equal( psz, g_szEvents[ i ] ) )
			{
				g_m_usGunEvents[ i ] = get_orig_retval( );

				break;
			}
		}
	}
}

public client_putinserver( id )
{
	g_bConnected |= ( 1 << id );

	g_bBot |= ( is_user_bot( id ) << id );
}

public fw_UpdateClientData( const id /* , sendweapons, cd */ )
{
	if ( ( g_bPrediction & ( 1 << id ) ) && ( g_bNoPredict & ( 1 << id ) ) )
	{
		if ( entity_get_int( id, EV_INT_waterlevel ) == 3 )
		{
			set_ent_data( id, "CBasePlayer", "m_bCanShoot", 0 );

			g_bInWater |= ( 1 << id );
		}

		else
		{
			/* 
				The game restores it on every frame...
				This is why we can't turn it on/off only if waterlevel changed.

				set_ent_data( id, "CBasePlayer", "m_bCanShoot", 1 );
			*/

			g_bInWater &= ~( 1 << id );
		}
	}

	return FMRES_IGNORED;
}

public fw_ClientUserInfoChanged( const pEntity /*, infobuffer */ )
{
	if ( ( g_bConnected & ( 1 << pEntity ) ) && !( g_bBot & ( 1 << pEntity ) ) )
	{
		query_client_cvar( pEntity, "cl_lw", "cvar_query_callback" );
	}

	return FMRES_IGNORED;
}

public cvar_query_callback( const id, const cvar[ ], const value[ ] /* , const param[ ] */ )
{
	if ( str_to_num( value ) )
	{
		g_bPrediction |= ( 1 << id );

		if ( g_bShootsUnderWater & ( 1 << g_iWpn[ id ] ) )
		{
			!g_bNoPredict ? ( p_UpdateClientData = register_forward( FM_UpdateClientData, "fw_UpdateClientData", ._post = false ) ) : 0;

			g_bNoPredict |= ( 1 << id );
		}
	}

	else
	{
		g_bInWater    &= ~( 1 << id );
		g_bPrediction &= ~( 1 << id );
		g_bNoPredict  &= ~( 1 << id );

		!g_bNoPredict ? unregister_forward( FM_UpdateClientData, p_UpdateClientData, .post = false ) : 0;
	}
}

public fw_Item_Holster_Post( const ent )
{
	static id;

	id = get_ent_data_entity( ent, "CBasePlayerItem", "m_pPlayer" );

	if ( g_bPrediction & ( 1 << id ) )
	{
		g_bNoPredict &= ~( 1 << id );

		!g_bNoPredict ? unregister_forward( FM_UpdateClientData, p_UpdateClientData, .post = false ) : 0;
	}
}

public fw_Item_Deploy_Post( const ent )
{
	static id;

	id = get_ent_data_entity( ent, "CBasePlayerItem", "m_pPlayer" );

	g_iWpn[ id ] = get_ent_data( ent, "CBasePlayerItem", "m_iId" );

	if ( ( g_bPrediction & ( 1 << id ) ) && ( g_bShootsUnderWater & ( 1 << g_iWpn[ id ] ) ) )
	{
		!g_bNoPredict ? ( p_UpdateClientData = register_forward( FM_UpdateClientData, "fw_UpdateClientData", ._post = false ) ) : 0;

		g_bNoPredict |= ( 1 << id );
	}
}

public UTIL_DryfireSound( const id, const Type )
{
	static Float:flGameTime;

	flGameTime = get_gametime( );

	if ( ( flGameTime - g_flTimeLast[ id ] ) >= 0.15 )
	{
		engfunc( EngFunc_EmitSound, id, CHAN_WEAPON, g_szDryfireSound[ Type ], 0.8, ATTN_NORM, 0, random_num( 95, 105 ) );

		g_flTimeLast[ id ] = flGameTime;
	}
}

public fw_Weapon_PrimaryAttack( const ent )
{
	g_iShooter = entity_get_edict( ent, EV_ENT_owner );

	/*
	---------------------------------------------------------------------------------------------------------------
										  ||
		Clients with weapon prediction	  ||	Bots;
		have cached g_bInWater condition. ||	Weapons which by default don't shoot underwater;
		Call the native only if needed -> ||	Weapons which by default shoots underwater but prediction disabled.
										  ||
	---------------------------------------------------------------------------------------------------------------
	*/

	if ( g_bInWater & ( 1 << g_iShooter ) || ( !( g_bNoPredict & ( 1 << g_iShooter ) ) && ( entity_get_int( g_iShooter, EV_INT_waterlevel ) == 3 ) ) )
	{
		g_m_iClip = get_ent_data( ent, "CBasePlayerWeapon", "m_iClip" );

		if ( g_m_iClip )
		{
			g_m_iId = g_iWpn[ g_iShooter ];

			if ( g_bShootsUnderWater & ( 1 << g_m_iId ) )
			{
				/*
					--------------------------------------------------------------------
					Forced exit from CWeapon::PrimaryAttack( ) -> CWeapon::WeaponFire( )
					--------------------------------------------------------------------
				*/

				/*
					( if (m_iClip <= 0) )
				*/

				set_ent_data( ent, "CBasePlayerWeapon", "m_iClip", 0 );

				/*
					The next adjustments attempts to 'bypass' the client-side prediction shot effects...
				*/

				/*
					Only clients with weapon prediction enabled
				*/

				if ( g_bPrediction & ( 1 << g_iShooter ) )
				{
					/*
						Let the server play the 'empty' sound only for pistols.
					*/

					if ( CSW_ALL_PISTOLS & ( 1 << g_m_iId ) )
					{
						/*
							Burst-Fire mode exception.
						*/

						if ( ( g_m_iId == CSW_GLOCK18 ) && ( get_ent_data( ent, "CBasePlayerWeapon", "m_iWeaponState" ) & CS_WPNSTATE_GLOCK18_BURST_MODE ) )
						{
							UTIL_DryfireSound( g_iShooter, 1 );
						}

						else
						{
							/*
								if (m_fFireOnEmpty)
							*/

							set_ent_data( ent, "CBasePlayerWeapon", "m_fFireOnEmpty", 1 );

							/*
								PlayEmptySound();
							*/

							/*
								CWeapon::WeaponFire( )

								return;
							*/
						}
					}

					else
					{
						UTIL_DryfireSound( g_iShooter, 0 );
					}

					set_ent_data_float( ent, "CBasePlayerWeapon", "m_flNextPrimaryAttack", 1.0 );

					!g_bRelease[ g_m_iId ] ? EnableHamForward( p_Item_PostFrame[ g_m_iId ] ) : 0;

					g_bRelease[ g_m_iId ] |= ( 1 << g_iShooter );
				}

				else
				{
					/*
						Let the server play the 'empty' sound for all weapons.
					*/

					/*
						if (m_fFireOnEmpty)
					*/

					set_ent_data( ent, "CBasePlayerWeapon", "m_fFireOnEmpty", 1 );

					/*
						PlayEmptySound();
					*/

					/*
						CWeapon::WeaponFire( )

						return;
					*/
				}
			}

			else
			{
				entity_set_int( g_iShooter, EV_INT_waterlevel, 2 );
			}

			g_bFaked |= ( 1 << g_iShooter );
		}
	}

	return HAM_IGNORED;
}

public fw_Weapon_PrimaryAttack_Post( const ent )
{
	if ( g_bFaked & ( 1 << g_iShooter ) )
	{
		if ( g_bShootsUnderWater & ( 1 << g_m_iId ) ) 
		{
			set_ent_data( ent, "CBasePlayerWeapon", "m_iClip", g_m_iClip );
		}

		else
		{
			entity_set_int( g_iShooter, EV_INT_waterlevel, 3 );

			engfunc( EngFunc_PlaybackEvent, 0, g_iShooter, g_m_usGunEvents[ g_m_iId ], 0.0, g_vecZero, g_vecZero, 0.0, 0.0, 0, 0, 0, 0 );
		}

		g_bFaked &= ~( 1 << g_iShooter );
	}

	return HAM_IGNORED;
}

public fw_Item_PostFrame( const ent )
{
	static id;

	id = entity_get_edict( ent, EV_ENT_owner );

	if ( g_bRelease[ g_m_iId ] & ( 1 << id ) )
	{
		set_ent_data_float( ent, "CBasePlayerWeapon", "m_flNextPrimaryAttack", -1.0 );

		g_bRelease[ g_m_iId ] &= ~( 1 << id );

		!g_bRelease[ g_m_iId ] ? DisableHamForward( p_Item_PostFrame[ g_m_iId ] ) : 0;
	}

	return HAM_IGNORED;
}

public fw_Client_Disconnect( const id )
{
	g_bConnected  &= ~( 1 << id );
	g_bFaked      &= ~( 1 << id );
	g_bPrediction &= ~( 1 << id );
	g_bBot        &= ~( 1 << id );
	g_bInWater    &= ~( 1 << id );
	g_bNoPredict  &= ~( 1 << id );

	g_bRelease[ g_iWpn[ id ] ] &= ~( 1 << id );

	g_iWpn[ id ] = CSW_NONE;

	g_flTimeLast[ id ] = 0.0;
}