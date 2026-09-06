import { z } from 'zod';
export const createRoomSchema = z.object({ body: z.object({ roomName: z.string().optional() }) });
export const mintTokenSchema = z.object({ params: z.object({ room_id: z.string().min(1) }), body: z.object({ identity: z.string().min(1) }) });
export const updateRoomStatusSchema = z.object({ params: z.object({ room_id: z.string().min(1) }), body: z.object({ status: z.enum(['open','locked','ended']) }) });
export const verifyCodeSchema = z.object({ params: z.object({ room_id: z.string().min(1) }), body: z.object({ code: z.string().length(4) }) });
