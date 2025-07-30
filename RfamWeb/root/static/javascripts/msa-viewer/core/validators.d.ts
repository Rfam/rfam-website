import { MSAData, MSASequence } from '../types';
/**
 * Validate MSA data structure
 */
export declare function validateMSAData(data: any): data is MSAData;
/**
 * Validate individual MSA sequence
 */
export declare function validateMSASequence(sequence: any): sequence is MSASequence;
