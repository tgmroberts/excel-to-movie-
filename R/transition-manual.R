#' Create an animation by specifying the frame membership directly
#'
#' This transition allows you to map a variable in your data to a specific frame
#' in the animation. No tweening of data will be made and the number of frames
#' in the animation will be decided by the number of levels in the frame
#' variable.
#'
#' @param frames The unquoted name of the column holding the frame membership.
#'
#' @family transitions
#'
#' @section Label variables:
#' `transition_states` makes the following variables available for string
#' literal interpretation:
#'
#' - **previous_frame** The name of the last frame the animation was at
#' - **current_frame** The name of the current frame
#' - **next_frame** The name of the next frame in the animation
#'
#' @export
#' @importFrom rlang enquo
#' @importFrom ggplot2 ggproto
transition_manual <- function(frames) {
  frames_quo <- enquo(frames)
  ggproto(NULL, TransitionManual, params = list(frames_quo = frames_quo))
}
#' @rdname gganimate-ggproto
#' @format NULL
#' @usage NULL
#' @export
#' @importFrom ggplot2 ggproto
#' @importFrom stringi stri_match
TransitionManual <- ggproto('TransitionManual', Transition,
  setup_params = function(self, data, params) {
    frames <- combine_levels(data, params$frames_quo)
    all_frames <- frames$levels
    row_id <- frames$values
    params$row_id <- row_id
    params$frame_info <- data.frame(
      previous_frame = c('', all_frames[-length(all_frames)]),
      current_frame = all_frames,
      next_frame = c(all_frames[-1], '')
    )
    params$nframes <- nrow(params$frame_info)
    params
  },
  map_data = function(self, data, params) {
    Map(function(d, id) {
      if (length(id) > 0) {
        d$group <- paste0(d$group, '_', id)
      }
      d
    }, d = data, id = params$row_id)
  },
  expand_data = function(self, data, type, ease, enter, exit, params, layer_index) {
    data
  },
  unmap_frames = function(self, data, params) {
    lapply(data, function(d) {
      split_panel <- stri_match(d$group, regex = '^(.+)_(.+)$')
      if (is.na(split_panel[1])) return(d)
      d$group <- as.integer(split_panel[, 2])
      d$PANEL <- paste0(d$PANEL, '_', split_panel[, 3])
      d
    })
  },
  remap_frames = function(self, data, params) {
    lapply(data, function(d) {
      split_panel <- stri_match(d$PANEL, regex = '^(.+)_(.+)$')
      if (is.na(split_panel[1])) return(d)
      d$PANEL <- as.integer(split_panel[, 2])
      d$group <- paste0(d$group, '_', split_panel[, 3])
      d
    })
  },
  finish_data = function(self, data, params) {
    lapply(data, function(d) {
      split_panel <- stri_match(d$group, regex = '^(.+)_(.+)$')
      if (is.na(split_panel[1])) return(d)
      d$group <- match(d$group, unique(d$group))
      empty_d <- d[0, , drop = FALSE]
      d <- split(d, as.integer(split_panel[, 3]))
      frames <- rep(list(empty_d), params$nframes)
      frames[as.integer(names(d))] <- d
      frames
    })
  },
  adjust_nframes = function(self, data, params) {
    statics <- self$static_layers(params)
    dynamics <- setdiff(seq_along(data), statics)
    if (length(dynamics) == 0) {
      params$nframes
    } else {
      length(data[[dynamics[1]]])
    }
  },
  get_frame_vars = function(self, params) {
    params$frame_info
  },
  static_layers = function(self, params) {
    which(lengths(params$row_id) == 0)
  }
)
