/**
 * @returns {Object<string, string>}
 */
export const processArgs = () => {
  const argsValues = process.argv.slice(1);
  const argsLen = argsValues.length;
  /**
   * @type {Object<string, string>}
   */
  const argsRecord = {};
  for (let i = 0; i < argsLen; i++) {
    const args = argsValues[i].slice(2);
    const split = args.split('=');
    if (!argsRecord[split[0]]) {
      argsRecord[split[0]] = split[1];
    }
  }
  return argsRecord;
};
