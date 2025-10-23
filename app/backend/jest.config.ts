import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  extensionsToTreatAsEsm: ['.ts'],
  transform: {
    '^.+\\.(t|j)s$': [
      'ts-jest',
      { useESM: true }
    ]
  },
  moduleNameMapper: {
    // Allow importing TS files written as ESM that reference .js in source
    '^(\\.{1,2}/.*)\\.js$': '$1'
  }
};

export default config;
