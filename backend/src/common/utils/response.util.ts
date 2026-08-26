/**
 * Standard API response helper
 */
export class ResponseUtil {
  static success<T>(data: T, message?: string) {
    return {
      success: true,
      data,
      message: message || 'Operation completed successfully',
      timestamp: new Date().toISOString(),
    };
  }

  static error(code: string, message: string, details?: any) {
    return {
      success: false,
      error: {
        code,
        message,
        details,
      },
      timestamp: new Date().toISOString(),
    };
  }

  static paginated<T>(
    data: T[],
    total: number,
    page: number,
    limit: number,
    message?: string,
  ) {
    return {
      success: true,
      data,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
      message: message || 'Operation completed successfully',
      timestamp: new Date().toISOString(),
    };
  }
}