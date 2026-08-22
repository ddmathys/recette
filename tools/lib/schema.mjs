import { z } from 'zod';

/**
 * Le schéma du contenu Kameo — source unique de vérité.
 *
 * Il sert à deux choses, et c'est ce qui garantit qu'elles ne divergent pas :
 *  1. contraindre la génération (`output_config.format`) ;
 *  2. valider ce qui entre dans `/content` (validate-content.mjs, lancé en CI).
 */

const ID = /^[a-z]{2}\.[a-z]+\.t\d+\.[a-z0-9-]+\.\d{2}$/;
const LEMMA_ID = /^[a-z]{2}\.[a-z0-9]+$/;
const CAN_DO = /^[ABC][12]\.(ORAL|ECRIT|ECOUTE)\.\d+$/;

export const SKILLS = ['ecrire', 'parler', 'ecouter'];
export const KINDS = ['translate', 'speak', 'listen', 'gap', 'dialogue', 'mcq'];

export const ItemSchema = z
  .object({
    id: z.string().regex(ID, 'format attendu : es.valencia.t1.theme.01'),
    kind: z.enum(KINDS),
    skill: z.enum(SKILLS),
    rung: z.enum(['r1', 'r2', 'r3', 'r4']),
    cefr: z.enum(['A1', 'A2', 'B1', 'B2', 'C1']),
    canDo: z.array(z.string().regex(CAN_DO)).min(1),
    city: z.string().min(2),
    tour: z.number().int().min(1).max(5),
    theme: z.string().min(2),
    lexemes: z.array(z.string().regex(LEMMA_ID)).min(1),
    grammar: z.array(z.string()).default([]),
    prompt: z.string().min(3),
    answer: z.string().min(1),
    alternates: z.array(z.string()).default([]),
    wordBank: z.array(z.string()).default([]),
    options: z.array(z.string()).default([]),
    difficulty: z.number().min(0).max(100),
    // Le texte à faire dire par la synthèse vocale. Séparé de `prompt` (la
    // consigne) et de `answer` (ce qu'on attend) : sans lui, impossible de
    // générer les audios en lot.
    audioText: z.string().nullable().default(null),
    audioRef: z.string().nullable().default(null),
    note: z.string().nullable().default(null),
  })
  .strict();

export const LessonSchema = z
  .object({
    id: z.string().min(3),
    title: z.string().min(3),
    canDo: z.array(z.string().regex(CAN_DO)).min(1),
    items: z.array(ItemSchema).min(4),
  })
  .strict();

export const CityPackSchema = z
  .object({
    schemaVersion: z.literal(1),
    lang: z.string().length(2),
    countryId: z.string().min(2),
    cityId: z.string().min(2),
    cityName: z.string().min(2),
    emoji: z.string().min(1),
    theme: z.string().min(2),
    tour: z.number().int().min(1).max(5),
    localExpression: z
      .object({
        text: z.string().min(2),
        translation: z.string().min(2),
        note: z.string().min(10),
        audioRef: z.string().nullable().default(null),
      })
      .strict(),
    lessons: z.array(LessonSchema).min(3),
    stampChallenge: z
      .object({
        title: z.string().min(3),
        items: z.array(ItemSchema).min(3),
      })
      .strict(),
    review: z
      .object({
        generatedBy: z.string(),
        generatedAt: z.string(),
        humanReviewed: z.boolean(),
        nativeReviewer: z.string().nullable().default(null),
      })
      .strict(),
  })
  .strict();

/** Ce que l'IA doit produire : le pack sans les métadonnées de revue. */
export const GeneratedPackSchema = CityPackSchema.omit({ review: true });
