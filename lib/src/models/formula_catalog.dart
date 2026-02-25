import 'package:worksheet/worksheet.dart' show FormulaFunction;
import 'package:worksheet_formula/worksheet_formula.dart' as wf;

/// Builds a list of [FormulaFunction] autocomplete entries from a
/// [wf.FunctionRegistry].
///
/// Uses curated signatures and descriptions for common functions.
/// Falls back to auto-generated signatures for any remaining functions.
List<FormulaFunction> buildAutocompleteFunctions(wf.FunctionRegistry registry) {
  final result = <FormulaFunction>[];
  for (final name in registry.names) {
    final fn = registry.get(name)!;
    final curated = _curatedFunctions[name];
    if (curated != null) {
      result.add(FormulaFunction(
        name: name,
        signature: curated.$1,
        description: curated.$2,
      ));
    } else {
      result.add(FormulaFunction(
        name: name,
        signature: _generateSignature(name, fn.minArgs, fn.maxArgs),
      ));
    }
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}

String _generateSignature(String name, int minArgs, int maxArgs) {
  if (minArgs == 0 && maxArgs == 0) return '$name()';
  final parts = <String>[];
  for (var i = 1; i <= minArgs; i++) {
    parts.add('arg$i');
  }
  if (maxArgs == -1) {
    parts.add('[arg${minArgs + 1}]');
    parts.add('...');
  } else {
    for (var i = minArgs + 1; i <= maxArgs; i++) {
      parts.add('[arg$i]');
    }
  }
  return '$name(${parts.join(', ')})';
}

/// Curated (signature, description) for common spreadsheet functions.
const _curatedFunctions = <String, (String, String)>{
  // --- Math ---
  'SUM': ('SUM(number1, [number2], ...)', 'Adds all numbers in a range.'),
  'SUMIF': (
    'SUMIF(range, criteria, [sum_range])',
    'Adds cells that meet a condition.'
  ),
  'SUMIFS': (
    'SUMIFS(sum_range, range1, criteria1, ...)',
    'Adds cells that meet multiple conditions.'
  ),
  'SUMPRODUCT': (
    'SUMPRODUCT(array1, [array2], ...)',
    'Sum of products of corresponding ranges.'
  ),
  'ABS': ('ABS(number)', 'Returns the absolute value.'),
  'ROUND': (
    'ROUND(number, num_digits)',
    'Rounds to a specified number of digits.'
  ),
  'ROUNDUP': (
    'ROUNDUP(number, num_digits)',
    'Rounds up, away from zero.'
  ),
  'ROUNDDOWN': (
    'ROUNDDOWN(number, num_digits)',
    'Rounds down, toward zero.'
  ),
  'CEILING': (
    'CEILING(number, significance)',
    'Rounds up to nearest multiple.'
  ),
  'FLOOR': (
    'FLOOR(number, significance)',
    'Rounds down to nearest multiple.'
  ),
  'INT': ('INT(number)', 'Rounds down to the nearest integer.'),
  'MOD': ('MOD(number, divisor)', 'Returns the remainder after division.'),
  'POWER': ('POWER(number, power)', 'Raises a number to a power.'),
  'SQRT': ('SQRT(number)', 'Returns the positive square root.'),
  'PRODUCT': (
    'PRODUCT(number1, [number2], ...)',
    'Multiplies its arguments.'
  ),
  'SIGN': ('SIGN(number)', 'Returns the sign of a number (-1, 0, or 1).'),
  'RAND': ('RAND()', 'Returns a random number between 0 and 1.'),
  'RANDBETWEEN': (
    'RANDBETWEEN(bottom, top)',
    'Returns a random integer between two values.'
  ),
  'PI': ('PI()', 'Returns the value of pi.'),
  'LN': ('LN(number)', 'Returns the natural logarithm.'),
  'LOG': ('LOG(number, [base])', 'Returns the logarithm of a number.'),
  'LOG10': ('LOG10(number)', 'Returns the base-10 logarithm.'),
  'EXP': ('EXP(number)', 'Returns e raised to a power.'),
  'EVEN': ('EVEN(number)', 'Rounds up to the nearest even integer.'),
  'ODD': ('ODD(number)', 'Rounds up to the nearest odd integer.'),
  'GCD': ('GCD(number1, [number2], ...)', 'Returns the greatest common divisor.'),
  'LCM': ('LCM(number1, [number2], ...)', 'Returns the least common multiple.'),
  'TRUNC': ('TRUNC(number, [num_digits])', 'Truncates to an integer.'),
  'MROUND': ('MROUND(number, multiple)', 'Rounds to a specified multiple.'),
  'QUOTIENT': (
    'QUOTIENT(numerator, denominator)',
    'Returns the integer portion of a division.'
  ),
  'COMBIN': (
    'COMBIN(number, number_chosen)',
    'Returns the number of combinations.'
  ),
  'FACT': ('FACT(number)', 'Returns the factorial.'),
  'SUMSQ': (
    'SUMSQ(number1, [number2], ...)',
    'Returns the sum of squares.'
  ),

  // --- Trigonometry ---
  'SIN': ('SIN(number)', 'Returns the sine of an angle (radians).'),
  'COS': ('COS(number)', 'Returns the cosine of an angle (radians).'),
  'TAN': ('TAN(number)', 'Returns the tangent of an angle (radians).'),
  'ASIN': ('ASIN(number)', 'Returns the arcsine in radians.'),
  'ACOS': ('ACOS(number)', 'Returns the arccosine in radians.'),
  'ATAN': ('ATAN(number)', 'Returns the arctangent in radians.'),
  'ATAN2': ('ATAN2(x_num, y_num)', 'Returns the arctangent from x and y.'),
  'DEGREES': ('DEGREES(angle)', 'Converts radians to degrees.'),
  'RADIANS': ('RADIANS(angle)', 'Converts degrees to radians.'),

  // --- Logical ---
  'IF': (
    'IF(condition, value_if_true, [value_if_false])',
    'Returns one value if true, another if false.'
  ),
  'AND': (
    'AND(logical1, [logical2], ...)',
    'TRUE if all arguments are true.'
  ),
  'OR': (
    'OR(logical1, [logical2], ...)',
    'TRUE if any argument is true.'
  ),
  'NOT': ('NOT(logical)', 'Reverses the value of its argument.'),
  'IFERROR': (
    'IFERROR(value, value_if_error)',
    'Returns value_if_error if value is an error.'
  ),
  'IFNA': (
    'IFNA(value, value_if_na)',
    'Returns value_if_na if value is #N/A.'
  ),
  'IFS': (
    'IFS(condition1, value1, [condition2, value2], ...)',
    'Checks multiple conditions, returns first true.'
  ),
  'SWITCH': (
    'SWITCH(expression, value1, result1, ...)',
    'Evaluates expression against a list of values.'
  ),
  'XOR': (
    'XOR(logical1, [logical2], ...)',
    'TRUE if an odd number of arguments are true.'
  ),
  'TRUE': ('TRUE()', 'Returns the logical value TRUE.'),
  'FALSE': ('FALSE()', 'Returns the logical value FALSE.'),

  // --- Text ---
  'CONCAT': (
    'CONCAT(text1, [text2], ...)',
    'Joins several text strings into one.'
  ),
  'CONCATENATE': (
    'CONCATENATE(text1, [text2], ...)',
    'Joins several text strings into one.'
  ),
  'LEFT': (
    'LEFT(text, [num_chars])',
    'Returns leftmost characters.'
  ),
  'RIGHT': (
    'RIGHT(text, [num_chars])',
    'Returns rightmost characters.'
  ),
  'MID': (
    'MID(text, start_num, num_chars)',
    'Returns characters from the middle of a text string.'
  ),
  'LEN': ('LEN(text)', 'Returns the number of characters.'),
  'LOWER': ('LOWER(text)', 'Converts text to lowercase.'),
  'UPPER': ('UPPER(text)', 'Converts text to uppercase.'),
  'PROPER': ('PROPER(text)', 'Capitalizes the first letter of each word.'),
  'TRIM': ('TRIM(text)', 'Removes extra spaces.'),
  'CLEAN': ('CLEAN(text)', 'Removes non-printable characters.'),
  'TEXT': (
    'TEXT(value, format_text)',
    'Formats a number as text with a format string.'
  ),
  'VALUE': ('VALUE(text)', 'Converts text to a number.'),
  'FIND': (
    'FIND(find_text, within_text, [start_num])',
    'Finds text within text (case-sensitive).'
  ),
  'SEARCH': (
    'SEARCH(find_text, within_text, [start_num])',
    'Finds text within text (case-insensitive).'
  ),
  'SUBSTITUTE': (
    'SUBSTITUTE(text, old_text, new_text, [instance])',
    'Substitutes new text for old text.'
  ),
  'REPLACE': (
    'REPLACE(old_text, start_num, num_chars, new_text)',
    'Replaces part of a text string.'
  ),
  'REPT': ('REPT(text, number_times)', 'Repeats text a given number of times.'),
  'EXACT': ('EXACT(text1, text2)', 'Checks if two strings are identical.'),
  'TEXTJOIN': (
    'TEXTJOIN(delimiter, ignore_empty, text1, ...)',
    'Joins text with a delimiter.'
  ),
  'CHAR': ('CHAR(number)', 'Returns the character for a code number.'),
  'CODE': ('CODE(text)', 'Returns the code for the first character.'),
  'T': ('T(value)', 'Returns text if value is text, empty otherwise.'),
  'TEXTBEFORE': (
    'TEXTBEFORE(text, delimiter, [instance])',
    'Returns text before a delimiter.'
  ),
  'TEXTAFTER': (
    'TEXTAFTER(text, delimiter, [instance])',
    'Returns text after a delimiter.'
  ),

  // --- Statistical ---
  'AVERAGE': (
    'AVERAGE(number1, [number2], ...)',
    'Returns the arithmetic mean.'
  ),
  'AVERAGEIF': (
    'AVERAGEIF(range, criteria, [average_range])',
    'Averages cells that meet a condition.'
  ),
  'AVERAGEIFS': (
    'AVERAGEIFS(average_range, range1, criteria1, ...)',
    'Averages cells that meet multiple conditions.'
  ),
  'COUNT': (
    'COUNT(value1, [value2], ...)',
    'Counts cells that contain numbers.'
  ),
  'COUNTA': (
    'COUNTA(value1, [value2], ...)',
    'Counts non-empty cells.'
  ),
  'COUNTBLANK': ('COUNTBLANK(range)', 'Counts empty cells in a range.'),
  'COUNTIF': (
    'COUNTIF(range, criteria)',
    'Counts cells that meet a condition.'
  ),
  'COUNTIFS': (
    'COUNTIFS(range1, criteria1, [range2, criteria2], ...)',
    'Counts cells that meet multiple conditions.'
  ),
  'MAX': (
    'MAX(number1, [number2], ...)',
    'Returns the largest value.'
  ),
  'MIN': (
    'MIN(number1, [number2], ...)',
    'Returns the smallest value.'
  ),
  'MEDIAN': (
    'MEDIAN(number1, [number2], ...)',
    'Returns the median value.'
  ),
  'MODE': (
    'MODE(number1, [number2], ...)',
    'Returns the most frequently occurring value.'
  ),
  'STDEV': (
    'STDEV(number1, [number2], ...)',
    'Estimates standard deviation based on a sample.'
  ),
  'STDEVP': (
    'STDEVP(number1, [number2], ...)',
    'Standard deviation based on the entire population.'
  ),
  'VAR': (
    'VAR(number1, [number2], ...)',
    'Estimates variance based on a sample.'
  ),
  'VARP': (
    'VARP(number1, [number2], ...)',
    'Variance based on the entire population.'
  ),
  'LARGE': (
    'LARGE(array, k)',
    'Returns the k-th largest value.'
  ),
  'SMALL': (
    'SMALL(array, k)',
    'Returns the k-th smallest value.'
  ),
  'RANK': (
    'RANK(number, ref, [order])',
    'Returns the rank of a number in a list.'
  ),
  'PERCENTILE': (
    'PERCENTILE(array, k)',
    'Returns the k-th percentile of values.'
  ),
  'FREQUENCY': (
    'FREQUENCY(data_array, bins_array)',
    'Returns a frequency distribution.'
  ),
  'SLOPE': ('SLOPE(known_ys, known_xs)', 'Returns the slope of a regression line.'),
  'PEARSON': (
    'PEARSON(array1, array2)',
    'Returns the Pearson correlation coefficient.'
  ),
  'CORREL': (
    'CORREL(array1, array2)',
    'Returns the correlation coefficient.'
  ),
  'FORECAST': (
    'FORECAST(x, known_ys, known_xs)',
    'Predicts a future value along a linear trend.'
  ),

  // --- Lookup & Reference ---
  'VLOOKUP': (
    'VLOOKUP(lookup_value, table_array, col_index, [range_lookup])',
    'Looks up a value in the first column of a range.'
  ),
  'HLOOKUP': (
    'HLOOKUP(lookup_value, table_array, row_index, [range_lookup])',
    'Looks up a value in the first row of a range.'
  ),
  'INDEX': (
    'INDEX(array, row_num, [col_num])',
    'Returns a value at a given position.'
  ),
  'MATCH': (
    'MATCH(lookup_value, lookup_array, [match_type])',
    'Returns the relative position of a value.'
  ),
  'XLOOKUP': (
    'XLOOKUP(lookup, lookup_array, return_array, [if_not_found], [match_mode])',
    'Searches a range and returns a corresponding item.'
  ),
  'XMATCH': (
    'XMATCH(lookup_value, lookup_array, [match_mode], [search_mode])',
    'Returns the relative position of a value.'
  ),
  'LOOKUP': (
    'LOOKUP(lookup_value, lookup_vector, [result_vector])',
    'Looks up a value in a range.'
  ),
  'CHOOSE': (
    'CHOOSE(index_num, value1, [value2], ...)',
    'Chooses a value from a list based on index.'
  ),
  'ROW': ('ROW([reference])', 'Returns the row number of a reference.'),
  'ROWS': ('ROWS(array)', 'Returns the number of rows in a reference.'),
  'COLUMN': (
    'COLUMN([reference])',
    'Returns the column number of a reference.'
  ),
  'COLUMNS': (
    'COLUMNS(array)',
    'Returns the number of columns in a reference.'
  ),
  'ADDRESS': (
    'ADDRESS(row_num, column_num, [abs_num], [a1])',
    'Creates a cell address as text.'
  ),
  'INDIRECT': (
    'INDIRECT(ref_text, [a1])',
    'Returns a reference from a text string.'
  ),
  'OFFSET': (
    'OFFSET(reference, rows, cols, [height], [width])',
    'Returns a reference offset from a starting point.'
  ),
  'TRANSPOSE': (
    'TRANSPOSE(array)',
    'Returns the transpose of an array.'
  ),

  // --- Date ---
  'DATE': ('DATE(year, month, day)', 'Creates a date from year, month, and day.'),
  'TODAY': ('TODAY()', "Returns today's date."),
  'NOW': ('NOW()', 'Returns the current date and time.'),
  'YEAR': ('YEAR(serial_number)', 'Returns the year of a date.'),
  'MONTH': ('MONTH(serial_number)', 'Returns the month of a date.'),
  'DAY': ('DAY(serial_number)', 'Returns the day of a date.'),
  'DAYS': ('DAYS(end_date, start_date)', 'Returns the number of days between two dates.'),
  'DATEDIF': (
    'DATEDIF(start_date, end_date, unit)',
    'Calculates the difference between two dates.'
  ),
  'DATEVALUE': ('DATEVALUE(date_text)', 'Converts a date string to a serial number.'),
  'WEEKDAY': (
    'WEEKDAY(serial_number, [return_type])',
    'Returns the day of the week.'
  ),
  'HOUR': ('HOUR(serial_number)', 'Returns the hour of a time value.'),
  'MINUTE': ('MINUTE(serial_number)', 'Returns the minutes of a time value.'),
  'SECOND': ('SECOND(serial_number)', 'Returns the seconds of a time value.'),
  'TIME': ('TIME(hour, minute, second)', 'Creates a time from hours, minutes, seconds.'),
  'EDATE': (
    'EDATE(start_date, months)',
    'Returns a date a given number of months away.'
  ),
  'EOMONTH': (
    'EOMONTH(start_date, months)',
    'Returns the last day of the month, months away.'
  ),
  'WEEKNUM': (
    'WEEKNUM(serial_number, [return_type])',
    'Returns the week number of a date.'
  ),
  'NETWORKDAYS': (
    'NETWORKDAYS(start_date, end_date, [holidays])',
    'Returns the number of working days between two dates.'
  ),
  'WORKDAY': (
    'WORKDAY(start_date, days, [holidays])',
    'Returns a date a given number of working days away.'
  ),
  'YEARFRAC': (
    'YEARFRAC(start_date, end_date, [basis])',
    'Returns the fraction of the year between two dates.'
  ),

  // --- Information ---
  'ISBLANK': ('ISBLANK(value)', 'Returns TRUE if the cell is empty.'),
  'ISERROR': ('ISERROR(value)', 'Returns TRUE if the value is any error.'),
  'ISNUMBER': ('ISNUMBER(value)', 'Returns TRUE if the value is a number.'),
  'ISTEXT': ('ISTEXT(value)', 'Returns TRUE if the value is text.'),
  'ISLOGICAL': ('ISLOGICAL(value)', 'Returns TRUE if the value is logical.'),
  'ISNA': ('ISNA(value)', 'Returns TRUE if the value is #N/A.'),
  'ISODD': ('ISODD(number)', 'Returns TRUE if the number is odd.'),
  'ISEVEN': ('ISEVEN(number)', 'Returns TRUE if the number is even.'),
  'TYPE': ('TYPE(value)', 'Returns the type of a value.'),
  'N': ('N(value)', 'Returns a value converted to a number.'),
  'NA': ('NA()', 'Returns the error value #N/A.'),

  // --- Array ---
  'UNIQUE': (
    'UNIQUE(array, [by_col], [exactly_once])',
    'Returns unique values from a range.'
  ),
  'FILTER': (
    'FILTER(array, include, [if_empty])',
    'Filters a range based on criteria.'
  ),
  'SORT': (
    'SORT(array, [sort_index], [sort_order], [by_col])',
    'Sorts the contents of a range.'
  ),
  'SORTBY': (
    'SORTBY(array, by_array1, [sort_order1], ...)',
    'Sorts a range by another range.'
  ),
  'SEQUENCE': (
    'SEQUENCE(rows, [columns], [start], [step])',
    'Generates a sequence of numbers.'
  ),
  'RANDARRAY': (
    'RANDARRAY([rows], [columns], [min], [max], [whole_number])',
    'Returns an array of random numbers.'
  ),
  'HSTACK': (
    'HSTACK(array1, [array2], ...)',
    'Stacks arrays horizontally.'
  ),
  'VSTACK': (
    'VSTACK(array1, [array2], ...)',
    'Stacks arrays vertically.'
  ),

  // --- Financial ---
  'PV': (
    'PV(rate, nper, pmt, [fv], [type])',
    'Returns the present value of an investment.'
  ),
  'FV': (
    'FV(rate, nper, pmt, [pv], [type])',
    'Returns the future value of an investment.'
  ),
  'PMT': (
    'PMT(rate, nper, pv, [fv], [type])',
    'Returns the periodic payment for a loan.'
  ),
  'RATE': (
    'RATE(nper, pmt, pv, [fv], [type], [guess])',
    'Returns the interest rate per period.'
  ),
  'NPER': (
    'NPER(rate, pmt, pv, [fv], [type])',
    'Returns the number of periods for an investment.'
  ),
  'NPV': (
    'NPV(rate, value1, [value2], ...)',
    'Returns the net present value.'
  ),
  'IRR': (
    'IRR(values, [guess])',
    'Returns the internal rate of return.'
  ),

  // --- Lambda ---
  'LAMBDA': (
    'LAMBDA([parameter1, ...], calculation)',
    'Creates a custom reusable function.'
  ),
  'MAP': (
    'MAP(array, lambda)',
    'Returns an array by applying a lambda to each element.'
  ),
  'REDUCE': (
    'REDUCE(initial_value, array, lambda)',
    'Reduces an array to a single value.'
  ),
  'SCAN': (
    'SCAN(initial_value, array, lambda)',
    'Scans an array, returning intermediate results.'
  ),
  'LET': (
    'LET(name1, value1, [name2, value2, ...], calculation)',
    'Assigns names to calculation results.'
  ),
  'BYROW': (
    'BYROW(array, lambda)',
    'Applies a lambda to each row.'
  ),
  'BYCOL': (
    'BYCOL(array, lambda)',
    'Applies a lambda to each column.'
  ),
  'MAKEARRAY': (
    'MAKEARRAY(rows, cols, lambda)',
    'Creates an array using a lambda.'
  ),
};
