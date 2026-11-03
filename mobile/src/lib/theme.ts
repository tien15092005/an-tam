// Bảng màu ấm, tương phản cao: dễ nhìn với người lớn tuổi, thân thiện với người con.
export const C = {
  bg: '#FBF7F2',
  surface: '#FFFFFF',
  ink: '#1F2233',
  muted: '#6B6F80',
  line: '#ECE5DB',
  primary: '#E86A33',
  primaryDark: '#C4521C',
  primarySoft: '#FDEBDF',
  navy: '#283A6B',
  navySoft: '#E8ECF6',
  ok: '#2F9E6B',
  okSoft: '#E3F4EB',
  warn: '#D98A1E',
  warnSoft: '#FDF1DC',
  danger: '#D94F4F',
  dangerSoft: '#FBE6E6',
  grey: '#EFEBE5',
};

export const F = {
  regular: 'BeVietnamPro_400Regular',
  medium: 'BeVietnamPro_500Medium',
  semi: 'BeVietnamPro_600SemiBold',
  bold: 'BeVietnamPro_700Bold',
  black: 'BeVietnamPro_800ExtraBold',
};

export const R = { sm: 10, md: 16, lg: 22, xl: 28 };

export const shadow = {
  shadowColor: '#5A4632',
  shadowOpacity: 0.08,
  shadowRadius: 12,
  shadowOffset: { width: 0, height: 4 },
  elevation: 2,
};

// Màu theo trạng thái lần uống thuốc / buổi tập
export const STATUS = {
  taken: { label: 'Đã uống', color: C.ok, bg: C.okSoft, icon: 'checkmark' },
  done: { label: 'Đã tập', color: C.ok, bg: C.okSoft, icon: 'checkmark' },
  skipped: { label: 'Bỏ qua', color: C.muted, bg: C.grey, icon: 'remove' },
  missed: { label: 'Bị quên', color: C.danger, bg: C.dangerSoft, icon: 'alert' },
  due: { label: 'Đến giờ', color: C.warn, bg: C.warnSoft, icon: 'alarm' },
  upcoming: { label: 'Sắp tới', color: C.muted, bg: C.grey, icon: 'time-outline' },
} as const;
