// Ambient type definitions for Supabase Edge Functions (Deno runtime)
// Mencegah error TS2304 ("Cannot find name 'Deno'") dan TS2307 ("Cannot find module 'https://...'") pada VS Code / TypeScript IDE.

declare const Deno: {
  env: {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
  };
  serve(handler: (req: Request) => Response | Promise<Response>): void;
};

declare module "https://deno.land/std@0.168.0/http/server.ts" {
  export function serve(handler: (req: Request) => Response | Promise<Response>): void;
}

declare module "https://*" {
  const content: any;
  export = content;
}

declare module "https://esm.sh/@supabase/supabase-js@2" {
  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: any
  ): any;
}

declare module "npm:ethers@6.13.4" {
  export const ethers: any;
}

declare module "npm:ethers*" {
  export const ethers: any;
}

declare module "npm:*" {
  export const ethers: any;
  const content: any;
  export default content;
}
