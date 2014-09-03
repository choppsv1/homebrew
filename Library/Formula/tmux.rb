require 'formula'

class Tmux < Formula
  homepage 'http://tmux.sourceforge.net'
  url 'https://downloads.sourceforge.net/project/tmux/tmux/tmux-1.9/tmux-1.9.tar.gz'
  #sha1 '43197e69716a0430a9e856c13df8ceae31783078'
  sha1 '815264268e63c6c85fe8784e06a840883fcfc6a2'

  bottle do
    cellar :any
    sha1 "258df085ed5fd3ff4374337294641bd057b81ff4" => :mavericks
    sha1 "3838e790a791d44464df6e7fcd25d8558d864d9c" => :mountain_lion
    sha1 "4368a7f81267c047050758338eb8f4207da12224" => :lion
  end

  head do
    url 'git://git.code.sf.net/p/tmux/tmux-code'

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  patch :p0, :DATA

  depends_on 'pkg-config' => :build
  depends_on 'libevent'

  def install
    system "sh", "autogen.sh" if build.head?

    ENV.append "LDFLAGS", '-lresolv'
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}"
    system "make install"

    bash_completion.install "examples/bash_completion_tmux.sh" => 'tmux'
    (share/'tmux').install "examples"
  end

  def caveats; <<-EOS.undent
    Example configurations have been installed to:
      #{share}/tmux/examples
    EOS
  end

  test do
    system "#{bin}/tmux", "-V"
  end
end

__END__
From 920989223fda9fec3f178f4a772eca920dcb8515 Mon Sep 17 00:00:00 2001
From: Arnis Lapsa <arnis.lapsa@gmail.com>
Date: Fri, 2 Aug 2013 16:15:46 +0300
Subject: [PATCH] 24bit colour support

---
 colour.c       |   6 ---
 input.c        |  30 +++++++++++++-
 screen-write.c |   2 +
 tmux.h         |  11 +++++
 tty.c          | 124 +++++++++++++++++++++++++++++++++++++++++----------------
 5 files changed, 132 insertions(+), 41 deletions(-)

diff --git a/colour.c b/colour.c
index da1cb42..09a969d 100644
--- colour.c
+++ colour.c
@@ -29,12 +29,6 @@
  * of the 256 colour palette.
  */
 
-/* An RGB colour. */
-struct colour_rgb {
-	u_char	r;
-	u_char	g;
-	u_char	b;
-};
 
 /* 256 colour RGB table, generated on first use. */
 struct colour_rgb *colour_rgb_256;
diff --git a/input.c b/input.c
index 30d3bb9..7c3ed44 100644
--- input.c
+++ input.c
@@ -1404,7 +1404,26 @@ input_csi_dispatch_sgr(struct input_ctx *ictx)
 
 		if (n == 38 || n == 48) {
 			i++;
-			if (input_get(ictx, i, 0, -1) != 5)
+			m=input_get(ictx, i, 0, -1);
+			if (m == 2){ // 24bit?
+				u_char r, g, b;
+				r = input_get(ictx, i+1, 0, -1);
+				g = input_get(ictx, i+2, 0, -1);
+				b = input_get(ictx, i+3, 0, -1);
+				struct colour_rgb rgb = {.r=r, .g=g, .b=b};
+				if (n == 38){
+					gc->flags &= ~GRID_FLAG_FG256;
+					gc->flags |= GRID_FLAG_FG24;
+					gc->fg_rgb = rgb;
+				} else if (n == 48){
+					gc->flags &= ~GRID_FLAG_BG256;
+					gc->flags |= GRID_FLAG_BG24;
+					gc->bg_rgb = rgb;
+				}
+				break;
+			}
+
+			if (m != 5)
 				continue;
 
 			i++;
@@ -1412,18 +1431,22 @@ input_csi_dispatch_sgr(struct input_ctx *ictx)
 			if (m == -1) {
 				if (n == 38) {
 					gc->flags &= ~GRID_FLAG_FG256;
+					gc->flags &= ~GRID_FLAG_FG24;
 					gc->fg = 8;
 				} else if (n == 48) {
 					gc->flags &= ~GRID_FLAG_BG256;
+					gc->flags &= ~GRID_FLAG_BG24;
 					gc->bg = 8;
 				}
 
 			} else {
 				if (n == 38) {
 					gc->flags |= GRID_FLAG_FG256;
+					gc->flags &= ~GRID_FLAG_FG24;
 					gc->fg = m;
 				} else if (n == 48) {
 					gc->flags |= GRID_FLAG_BG256;
+					gc->flags &= ~GRID_FLAG_BG24;
 					gc->bg = m;
 				}
 			}
@@ -1482,10 +1505,12 @@ input_csi_dispatch_sgr(struct input_ctx *ictx)
 		case 36:
 		case 37:
 			gc->flags &= ~GRID_FLAG_FG256;
+			gc->flags &= ~GRID_FLAG_FG24;
 			gc->fg = n - 30;
 			break;
 		case 39:
 			gc->flags &= ~GRID_FLAG_FG256;
+			gc->flags &= ~GRID_FLAG_FG24;
 			gc->fg = 8;
 			break;
 		case 40:
@@ -1497,10 +1522,12 @@ input_csi_dispatch_sgr(struct input_ctx *ictx)
 		case 46:
 		case 47:
 			gc->flags &= ~GRID_FLAG_BG256;
+			gc->flags &= ~GRID_FLAG_BG24;
 			gc->bg = n - 40;
 			break;
 		case 49:
 			gc->flags &= ~GRID_FLAG_BG256;
+			gc->flags &= ~GRID_FLAG_BG24;
 			gc->bg = 8;
 			break;
 		case 90:
@@ -1523,6 +1550,7 @@ input_csi_dispatch_sgr(struct input_ctx *ictx)
 		case 106:
 		case 107:
 			gc->flags &= ~GRID_FLAG_BG256;
+			gc->flags &= ~GRID_FLAG_BG24;
 			gc->bg = n - 10;
 			break;
 		}
diff --git a/tmux.h b/tmux.h
index cc1c79e..1fc6043 100644
--- tmux.h
+++ tmux.h
@@ -713,10 +713,19 @@ struct utf8_data {
 #define GRID_FLAG_FG256 0x1
 #define GRID_FLAG_BG256 0x2
 #define GRID_FLAG_PADDING 0x4
+#define GRID_FLAG_FG24 0x8
+#define GRID_FLAG_BG24 0x10
 
 /* Grid line flags. */
 #define GRID_LINE_WRAPPED 0x1
 
+/* An RGB colour. */
+struct colour_rgb {
+	u_char	r;
+	u_char	g;
+	u_char	b;
+};
+
 /* Grid cell data. */
 struct grid_cell {
 	u_char	attr;
@@ -726,6 +735,8 @@ struct grid_cell {
 
 	u_char	xstate; /* top 4 bits width, bottom 4 bits size */
 	u_char	xdata[UTF8_SIZE];
+	struct colour_rgb fg_rgb;
+	struct colour_rgb bg_rgb;
 } __packed;
 
 /* Grid line. */
diff --git a/tty.c b/tty.c
index d5b1aec..61b65b1 100644
--- tty.c
+++ tty.c
@@ -35,6 +35,7 @@ void	tty_read_callback(struct bufferevent *, void *);
 void	tty_error_callback(struct bufferevent *, short, void *);
 
 int	tty_try_256(struct tty *, u_char, const char *);
+int	tty_try_24(struct tty *, struct colour_rgb, const char *);
 
 void	tty_colours(struct tty *, const struct grid_cell *);
 void	tty_check_fg(struct tty *, struct grid_cell *);
@@ -1380,14 +1381,23 @@ tty_attributes(struct tty *tty, const struct grid_cell *gc)
 
 void
 tty_colours(struct tty *tty, const struct grid_cell *gc)
-{
+{	
 	struct grid_cell	*tc = &tty->cell;
 	u_char			 fg = gc->fg, bg = gc->bg, flags = gc->flags;
 	int			 have_ax, fg_default, bg_default;
 
 	/* No changes? Nothing is necessary. */
 	if (fg == tc->fg && bg == tc->bg &&
-	    ((flags ^ tc->flags) & (GRID_FLAG_FG256|GRID_FLAG_BG256)) == 0)
+	    tc->fg_rgb.r == gc->fg_rgb.r &&
+	    tc->fg_rgb.g == gc->fg_rgb.g &&
+	    tc->fg_rgb.b == gc->fg_rgb.b &&
+
+	    tc->bg_rgb.r == gc->bg_rgb.r &&
+	    tc->bg_rgb.g == gc->bg_rgb.g &&
+	    tc->bg_rgb.b == gc->bg_rgb.b &&
+	    ((flags ^ tc->flags) & (GRID_FLAG_FG256|GRID_FLAG_BG256|GRID_FLAG_FG24|GRID_FLAG_BG24)) == 0
+	    
+	    )
 		return;
 
 	/*
@@ -1396,8 +1406,8 @@ tty_colours(struct tty *tty, const struct grid_cell *gc)
 	 * case if only one is default need to fall onward to set the other
 	 * colour.
 	 */
-	fg_default = (fg == 8 && !(flags & GRID_FLAG_FG256));
-	bg_default = (bg == 8 && !(flags & GRID_FLAG_BG256));
+	fg_default = (fg == 8 && !(flags & GRID_FLAG_FG256) && !(flags & GRID_FLAG_FG24));
+	bg_default = (bg == 8 && !(flags & GRID_FLAG_BG256) && !(flags & GRID_FLAG_BG24));
 	if (fg_default || bg_default) {
 		/*
 		 * If don't have AX but do have op, send sgr0 (op can't
@@ -1411,39 +1421,49 @@ tty_colours(struct tty *tty, const struct grid_cell *gc)
 			tty_reset(tty);
 		else {
 			if (fg_default &&
-			    (tc->fg != 8 || tc->flags & GRID_FLAG_FG256)) {
+			    (tc->fg != 8 || tc->flags & GRID_FLAG_FG256 || tc->flags & GRID_FLAG_FG24)) {
 				if (have_ax)
 					tty_puts(tty, "\033[39m");
 				else if (tc->fg != 7 ||
-				    tc->flags & GRID_FLAG_FG256)
+				    tc->flags & GRID_FLAG_FG256 ||
+				    tc->flags & GRID_FLAG_FG24)
 					tty_putcode1(tty, TTYC_SETAF, 7);
 				tc->fg = 8;
 				tc->flags &= ~GRID_FLAG_FG256;
+				tc->flags &= ~GRID_FLAG_FG24;
 			}
 			if (bg_default &&
-			    (tc->bg != 8 || tc->flags & GRID_FLAG_BG256)) {
+			    (tc->bg != 8 || tc->flags & GRID_FLAG_BG256 || tc->flags & GRID_FLAG_BG24)) {
 				if (have_ax)
 					tty_puts(tty, "\033[49m");
 				else if (tc->bg != 0 ||
-				    tc->flags & GRID_FLAG_BG256)
+				    tc->flags & GRID_FLAG_BG256 ||
+				    tc->flags & GRID_FLAG_BG24)
 					tty_putcode1(tty, TTYC_SETAB, 0);
 				tc->bg = 8;
 				tc->flags &= ~GRID_FLAG_BG256;
+				tc->flags &= ~GRID_FLAG_BG24;
 			}
 		}
 	}
 
 	/* Set the foreground colour. */
-	if (!fg_default && (fg != tc->fg ||
-	    ((flags & GRID_FLAG_FG256) != (tc->flags & GRID_FLAG_FG256))))
+	if (!fg_default && (fg != tc->fg || ((flags & GRID_FLAG_FG256) != (tc->flags & GRID_FLAG_FG256)) || 
+	    (
+		    ( tc->fg_rgb.r!=gc->fg_rgb.r || tc->fg_rgb.g!=gc->fg_rgb.g || tc->fg_rgb.b!=gc->fg_rgb.b ) ||
+		    ((flags & GRID_FLAG_FG24) != (tc->flags & GRID_FLAG_FG24))
+	    )))
 		tty_colours_fg(tty, gc);
 
 	/*
 	 * Set the background colour. This must come after the foreground as
 	 * tty_colour_fg() can call tty_reset().
 	 */
-	if (!bg_default && (bg != tc->bg ||
-	    ((flags & GRID_FLAG_BG256) != (tc->flags & GRID_FLAG_BG256))))
+	if (!bg_default && (bg != tc->bg || ((flags & GRID_FLAG_BG256) != (tc->flags & GRID_FLAG_BG256)) || 
+	    (
+		    ( tc->bg_rgb.r!=gc->bg_rgb.r || tc->bg_rgb.g!=gc->bg_rgb.g || tc->bg_rgb.b!=gc->bg_rgb.b ) ||
+		    ((flags & GRID_FLAG_BG24) != (tc->flags & GRID_FLAG_BG24))
+	    )))
 		tty_colours_bg(tty, gc);
 }
 
@@ -1453,7 +1473,7 @@ tty_check_fg(struct tty *tty, struct grid_cell *gc)
 	u_int	colours;
 
 	/* Is this a 256-colour colour? */
-	if (gc->flags & GRID_FLAG_FG256) {
+	if (gc->flags & GRID_FLAG_FG256 && !(gc->flags & GRID_FLAG_BG24)) {
 		/* And not a 256 colour mode? */
 		if (!(tty->term->flags & TERM_256COLOURS) &&
 		    !(tty->term_flags & TERM_256COLOURS)) {
@@ -1482,7 +1502,7 @@ tty_check_bg(struct tty *tty, struct grid_cell *gc)
 	u_int	colours;
 
 	/* Is this a 256-colour colour? */
-	if (gc->flags & GRID_FLAG_BG256) {
+	if (gc->flags & GRID_FLAG_BG256 && !(gc->flags & GRID_FLAG_BG24)) {
 		/*
 		 * And not a 256 colour mode? Translate to 16-colour
 		 * palette. Bold background doesn't exist portably, so just
@@ -1511,15 +1531,29 @@ void
 tty_colours_fg(struct tty *tty, const struct grid_cell *gc)
 {
 	struct grid_cell	*tc = &tty->cell;
+	struct colour_rgb	 rgb= gc->fg_rgb;
 	u_char			 fg = gc->fg;
 	char			 s[32];
 
+	tc->flags &= ~GRID_FLAG_FG256;
+	tc->flags &= ~GRID_FLAG_FG24;
+
+	/* Is this a 24-colour colour? */
+	if (gc->flags & GRID_FLAG_FG24) {
+//log_debug("trying to output 24bit fg");
+		if (tty_try_24(tty, rgb, "38") == 0){
+			tc->fg_rgb = rgb;
+			tc->flags |= gc->flags & GRID_FLAG_FG24;
+		}
+		return;
+	}
+
 	/* Is this a 256-colour colour? */
 	if (gc->flags & GRID_FLAG_FG256) {
-		/* Try as 256 colours. */
-		if (tty_try_256(tty, fg, "38") == 0)
-			goto save_fg;
-		/* Else already handled by tty_check_fg. */
+		if (tty_try_256(tty, fg, "38") == 0){
+			tc->fg = fg;
+			tc->flags |= gc->flags & GRID_FLAG_FG256;
+		}
 		return;
 	}
 
@@ -1527,32 +1561,41 @@ tty_colours_fg(struct tty *tty, const struct grid_cell *gc)
 	if (fg >= 90 && fg <= 97) {
 		xsnprintf(s, sizeof s, "\033[%dm", fg);
 		tty_puts(tty, s);
-		goto save_fg;
+		tc->fg = fg;
+		return;
 	}
 
 	/* Otherwise set the foreground colour. */
 	tty_putcode1(tty, TTYC_SETAF, fg);
-
-save_fg:
-	/* Save the new values in the terminal current cell. */
 	tc->fg = fg;
-	tc->flags &= ~GRID_FLAG_FG256;
-	tc->flags |= gc->flags & GRID_FLAG_FG256;
 }
 
 void
 tty_colours_bg(struct tty *tty, const struct grid_cell *gc)
 {
 	struct grid_cell	*tc = &tty->cell;
+	struct colour_rgb	 rgb= gc->bg_rgb;
 	u_char			 bg = gc->bg;
 	char			 s[32];
 
+	tc->flags &= ~GRID_FLAG_BG256;
+	tc->flags &= ~GRID_FLAG_BG24;
+
+	/* Is this a 24-colour colour? */
+	if (gc->flags & GRID_FLAG_BG24) {
+		if (tty_try_24(tty, rgb, "48") == 0){
+			tc->bg_rgb = rgb;
+			tc->flags |= gc->flags & GRID_FLAG_BG24;
+		}
+		return;
+	}
+
 	/* Is this a 256-colour colour? */
 	if (gc->flags & GRID_FLAG_BG256) {
-		/* Try as 256 colours. */
-		if (tty_try_256(tty, bg, "48") == 0)
-			goto save_bg;
-		/* Else already handled by tty_check_bg. */
+		if (tty_try_256(tty, bg, "48") == 0){
+			tc->bg = bg;
+			tc->flags |= gc->flags & GRID_FLAG_BG256;
+		}
 		return;
 	}
 
@@ -1562,20 +1605,16 @@ tty_colours_bg(struct tty *tty, const struct grid_cell *gc)
 		if (tty_term_number(tty->term, TTYC_COLORS) >= 16) {
 			xsnprintf(s, sizeof s, "\033[%dm", bg + 10);
 			tty_puts(tty, s);
-			goto save_bg;
+			tc->bg = bg;
 		}
 		bg -= 90;
+		return;
 		/* no such thing as a bold background */
 	}
 
 	/* Otherwise set the background colour. */
 	tty_putcode1(tty, TTYC_SETAB, bg);
-
-save_bg:
-	/* Save the new values in the terminal current cell. */
 	tc->bg = bg;
-	tc->flags &= ~GRID_FLAG_BG256;
-	tc->flags |= gc->flags & GRID_FLAG_BG256;
 }
 
 int
@@ -1592,6 +1631,23 @@ tty_try_256(struct tty *tty, u_char colour, const char *type)
 	return (0);
 }
 
+
+int
+tty_try_24(struct tty *tty, struct colour_rgb rgb, const char *type)
+{
+	char	s[32];
+
+	//if (!(tty->term->flags & TERM_256COLOURS) &&
+	//    !(tty->term_flags & TERM_256COLOURS))
+	//	return (-1);
+
+	//xsnprintf(s, sizeof s, "\033[%s;5;%hhum", type, colour);
+	xsnprintf(s, sizeof s, "\033[%s;2;%hhu;%hhu;%hhum", type, rgb.r, rgb.g, rgb.b);
+//log_debug("24bit output: %s",s);
+	tty_puts(tty, s);
+	return (0);
+}
+
 void
 tty_bell(struct tty *tty)
 {
-- 
1.8.1.2
