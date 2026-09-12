import { createTheme } from '@mui/material/styles'

// SportSphere design system — defined once, referenced everywhere.
export const palette = {
  primary: '#FF6A13', // brand orange
  primaryHover: '#FF8A42', // accent / hover orange
  black: '#0D0D0D',
  background: '#FAFAF8',
  surface: '#FFFFFF',
  border: '#E5E5E0',
  textSecondary: '#55554F',
  textMuted: '#8A8A82',
  success: '#2E7D32',
  warning: '#B26A00',
  error: '#C62828',
  info: '#1565C0',
}

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: palette.primary, contrastText: '#FFFFFF' },
    secondary: { main: palette.primaryHover },
    background: { default: palette.background, paper: palette.surface },
    text: { primary: palette.black, secondary: palette.textSecondary },
    success: { main: palette.success },
    warning: { main: palette.warning },
    error: { main: palette.error },
    info: { main: palette.info },
    divider: palette.border,
  },
  typography: {
    fontFamily: "'Lato', 'Helvetica Neue', Helvetica, Arial, sans-serif",
    h4: { fontWeight: 700 },
    h5: { fontWeight: 700 },
    h6: { fontWeight: 700 },
    button: { fontWeight: 600, textTransform: 'none' },
  },
  shape: { borderRadius: 10 },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: { backgroundColor: palette.background },
      },
    },
    MuiPaper: {
      styleOverrides: {
        root: { backgroundImage: 'none' },
      },
    },
    MuiButton: {
      defaultProps: { disableElevation: true },
    },
    MuiChip: {
      styleOverrides: {
        root: { fontWeight: 600 },
      },
    },
  },
})

export default theme
